'use strict';

const { Contract } = require('fabric-contract-api');

const Status = Object.freeze({
    UNKNOWN: 0,
    VALID: 1,
    REVOKED: 2,
});

const STATUS_TRANSITIONS = Object.freeze({
    [Status.UNKNOWN]: new Set([Status.VALID]),
    [Status.VALID]: new Set([Status.REVOKED]),
    [Status.REVOKED]: new Set(),
});

const TIMESTAMP_INDEX = 'timestamp~pid';

class ResourceEventsV2 extends Contract {
    // Set the contract name used by Fabric clients.
    constructor() {
        super('ResourceEventsV2');
    }

    // Store a new resource with UNKNOWN status and index its transaction timestamp.
    async CreateResource(ctx, pid, uri, hash, owners) {
        pid = this._requiredString(pid, 'pid');
        uri = this._requiredString(uri, 'uri');
        hash = this._requiredString(hash, 'hash');
        const parsedOwners = this._parseOwners(owners);

        if (await this.ResourceExists(ctx, pid)) {
            throw new Error(`The resource ${pid} already exists`);
        }

        const timestamp = this._transactionTimestamp(ctx);
        const creator = this._caller(ctx);
        const resource = {
            pid,
            uri,
            hash,
            timestamp,
            owners: parsedOwners,
            status: Status.UNKNOWN,
            creator,
        };

        const resourceBuffer = Buffer.from(JSON.stringify(resource));
        await ctx.stub.putState(pid, resourceBuffer);
        await ctx.stub.putState(this._timestampKey(ctx, timestamp, pid), Buffer.from(pid));
        ctx.stub.setEvent('CreateResource', resourceBuffer);
        return JSON.stringify(resource);
    }

    // Apply an authorized status transition and record who performed it and when.
    async UpdateResourceStatus(ctx, pid, newStatus) {
        pid = this._requiredString(pid, 'pid');
        const status = this._parseStatus(newStatus);
        const resource = await this._getResource(ctx, pid);

        this._assertCanUpdate(ctx, resource);
        const allowed = STATUS_TRANSITIONS[resource.status];
        if (!allowed || !allowed.has(status)) {
            throw new Error(`Invalid status transition from ${resource.status} to ${status}`);
        }

        resource.status = status;
        resource.updatedAt = this._transactionTimestamp(ctx);
        resource.updatedBy = this._caller(ctx);

        const resourceBuffer = Buffer.from(JSON.stringify(resource));
        await ctx.stub.putState(pid, resourceBuffer);
        ctx.stub.setEvent('UpdateResourceStatus', resourceBuffer);
        return JSON.stringify(resource);
    }

    // Return the resource identified by its PID as JSON.
    async ReadResource(ctx, pid) {
        return JSON.stringify(await this._getResource(ctx, this._requiredString(pid, 'pid')));
    }

    // Return resources created within an inclusive range of Unix timestamps in seconds.
    async GetResourcesByTimestamp(ctx, startTs, endTs) {
        const start = this._parseTimestamp(startTs, 'startTs');
        const end = this._parseTimestamp(endTs, 'endTs');
        if (start > end) {
            throw new Error('startTs must be less than or equal to endTs');
        }

        // Fabric reserves composite keys (which begin with a null byte) and
        // rejects them as boundaries for getStateByRange. Iterate only over
        // this composite index and filter its ordered timestamp attribute.
        const iterator = await ctx.stub.getStateByPartialCompositeKey(TIMESTAMP_INDEX, []);
        const resources = [];

        try {
            while (true) {
                const result = await iterator.next();
                if (result.value) {
                    const { attributes } = ctx.stub.splitCompositeKey(result.value.key);
                    const timestamp = Number(attributes[0]);

                    if (timestamp >= start && timestamp <= end) {
                        const pid = attributes[1] || result.value.value.toString('utf8');
                        resources.push(await this._getResource(ctx, pid));
                    }
                }
                if (result.done) break;
            }
        } finally {
            await iterator.close();
        }

        return JSON.stringify(resources);
    }

    // Return all resources in the V2 timestamp index.
    async ReadAllResources(ctx) {
        // V2 resources are identified by their creation-time index entries.
        return this.GetResourcesByTimestamp(ctx, '0', String(Number.MAX_SAFE_INTEGER));
    }

    // Return recorded resource versions with transaction IDs, timestamps, and deletion flags.
    async GetResourceHistory(ctx, pid) {
        pid = this._requiredString(pid, 'pid');
        if (!(await this.ResourceExists(ctx, pid))) {
            throw new Error(`The resource ${pid} does not exist`);
        }

        const iterator = await ctx.stub.getHistoryForKey(pid);
        const history = [];
        try {
            while (true) {
                const result = await iterator.next();
                if (result.value) {
                    const item = result.value;
                    history.push({
                        txId: item.txId,
                        timestamp: this._protobufTimestamp(item.timestamp),
                        isDelete: item.isDelete,
                        value: item.isDelete ? null : JSON.parse(item.value.toString('utf8')),
                    });
                }
                if (result.done) break;
            }
        } finally {
            await iterator.close();
        }
        return JSON.stringify(history);
    }

    // Check whether the PID has a non-empty value in the world state.
    async ResourceExists(ctx, pid) {
        pid = this._requiredString(pid, 'pid');
        const resourceJSON = await ctx.stub.getState(pid);
        return Boolean(resourceJSON && resourceJSON.length > 0);
    }

    // Load and parse a resource, rejecting missing PIDs.
    async _getResource(ctx, pid) {
        const resourceJSON = await ctx.stub.getState(pid);
        if (!resourceJSON || resourceJSON.length === 0) {
            throw new Error(`The resource ${pid} does not exist`);
        }
        return JSON.parse(resourceJSON.toString('utf8'));
    }

    // Allow updates only for an owner, the creator, or a caller with the admin role.
    _assertCanUpdate(ctx, resource) {
        const caller = this._caller(ctx);
        const isOwner = resource.owners.includes(caller.id) || resource.owners.includes(caller.mspId);
        const isCreator = resource.creator && resource.creator.id === caller.id;
        const isAdmin = ctx.clientIdentity.getAttributeValue('role') === 'admin';

        if (!isOwner && !isCreator && !isAdmin) {
            throw new Error(`Caller ${caller.id} is not authorized to update resource ${resource.pid}`);
        }
    }

    // Extract the submitting client's identity and MSP ID.
    _caller(ctx) {
        return {
            id: ctx.clientIdentity.getID(),
            mspId: ctx.clientIdentity.getMSPID(),
        };
    }

    // Validate a non-empty owners array, then trim, deduplicate, and sort its entries.
    _parseOwners(owners) {
        let parsed;
        try {
            parsed = Array.isArray(owners) ? owners : JSON.parse(owners);
        } catch (error) {
            throw new Error('owners must be a JSON array of identity IDs or MSP IDs');
        }
        if (!Array.isArray(parsed) || parsed.length === 0) {
            throw new Error('owners must be a non-empty JSON array');
        }
        const normalized = parsed.map((owner) => this._requiredString(owner, 'owner'));
        return [...new Set(normalized)].sort();
    }

    // Convert the input to a supported numeric status.
    _parseStatus(value) {
        const status = Number(value);
        if (!Number.isInteger(status) || !Object.values(Status).includes(status)) {
            throw new Error(`The status ${value} is not valid`);
        }
        return status;
    }

    // Validate a timestamp as a non-negative safe integer.
    _parseTimestamp(value, name) {
        const timestamp = Number(value);
        if (!Number.isSafeInteger(timestamp) || timestamp < 0) {
            throw new Error(`${name} must be a non-negative safe integer`);
        }
        return timestamp;
    }

    // Read the transaction timestamp in Unix seconds.
    _transactionTimestamp(ctx) {
        return this._protobufTimestamp(ctx.stub.getTxTimestamp());
    }

    // Extract and validate whole seconds from a Fabric protobuf timestamp.
    _protobufTimestamp(timestamp) {
        const seconds = typeof timestamp.seconds === 'object'
            ? Number(timestamp.seconds.toString())
            : Number(timestamp.seconds);
        if (!Number.isSafeInteger(seconds) || seconds < 0) {
            throw new Error('Transaction timestamp is outside the supported range');
        }
        return seconds;
    }

    // Build the composite key linking a creation timestamp to a resource PID.
    _timestampKey(ctx, timestamp, pid) {
        return ctx.stub.createCompositeKey(TIMESTAMP_INDEX, [this._padTimestamp(timestamp), pid]);
    }

    // Pad timestamps so lexicographic ordering matches chronological ordering.
    _padTimestamp(timestamp) {
        return String(timestamp).padStart(16, '0');
    }

    // Require a non-blank string and remove surrounding whitespace.
    _requiredString(value, name) {
        if (typeof value !== 'string' || value.trim() === '') {
            throw new Error(`${name} must be a non-empty string`);
        }
        return value.trim();
    }
}

module.exports = ResourceEventsV2;
module.exports.Status = Status;
