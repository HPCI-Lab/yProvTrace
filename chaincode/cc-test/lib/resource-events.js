'use strict';

const { Contract } = require('fabric-contract-api');

const Status = {
    UNKNOWN: 0,
	VALID: 1,
	REVOKED: 2
};

class ResourceEvents extends Contract {

	// CreateResource issues a new resource to the world state with given details.
	async CreateResource(ctx, pid, uri, hash, timestamp, owners) {
		const exists = await this.ResourceExists(ctx, pid);
		if (exists) 
			throw new Error(`The resource ${pid} already exists`);
		
		const resource = {
			pid: pid,
			uri: uri,
			hash: hash,
			timestamp: timestamp,
			owners: owners,
			status: Status.UNKNOWN
		};

		const resourceBuffer = Buffer.from(JSON.stringify(resource));
		await ctx.stub.putState(pid, resourceBuffer);
		ctx.stub.setEvent('CreateResource', resourceBuffer);
		return JSON.stringify(resource);
	}

	// UpdateResourceStatus updates the status of resource stored in the world state with given id.
	async UpdateResourceStatus(ctx, pid, newStatus) {
		const exists = await this.ResourceExists(ctx, pid);
		if (!exists) 
			throw new Error(`The resource ${pid} does not exist`);
		
		const resourceJSON = await ctx.stub.getState(pid);
		const resource = JSON.parse(resourceJSON.toString());

		// Check that the new status is valid
		if (!Object.values(Status).includes(parseInt(newStatus))) {
			throw new Error(`The status ${newStatus} is not valid`);
		}
		
		// Update the status
		resource.status = parseInt(newStatus);
		const resourceBuffer = Buffer.from(JSON.stringify(resource));
		await ctx.stub.putState(pid, resourceBuffer);
		ctx.stub.setEvent('UpdateResourceStatus', resourceBuffer);
		return JSON.stringify(resource);
	}

	// ReadResource returns the resource stored in the world state with given id.
	async ReadResource(ctx, pid) {
		const exists = await this.ResourceExists(ctx, pid);
		if (!exists) 
			throw new Error(`The resource ${pid} does not exist`);
		
		const resourceJSON = await ctx.stub.getState(pid);
		return resourceJSON.toString();
	}

	// GetResourcesByTimestamp returns all resources within the given timestamp range.
	async GetResourcesByTimestamp(ctx, startTs, endTs) {
		const allResults = [];
		const iterator = await ctx.stub.getStateByRange("", "");

		while (true) {
			const res = await iterator.next();
			if (res.value && res.value.value.toString()) {
				const resource = JSON.parse(res.value.value.toString("utf8"));

				// ensure timestamp is numeric for comparison
				const ts = Number(resource.timestamp);
				if (ts >= Number(startTs) && ts <= Number(endTs)) {
					allResults.push(resource);
				}
			}
			if (res.done) {
				await iterator.close();
				break;
			}
		}
		return JSON.stringify(allResults);
	}

	// ReadAllResources returns all resources found in the world state.
	async ReadAllResources(ctx) {
		const allResults = [];
		const iterator = await ctx.stub.getStateByRange('', '');
		let result = await iterator.next();
		while (!result.done) {
			const strValue = result.value.value.toString('utf8');
			let record;
			try {
				record = JSON.parse(strValue);
			} catch (err) {
				console.log(err);
				record = strValue;
			}
			allResults.push(record);
			result = await iterator.next();
		}
		await iterator.close();
		return JSON.stringify(allResults);
	}

	// ResourceExists returns true when resource with given id exists in world state.
	async ResourceExists(ctx, pid) {
		const resourceJSON = await ctx.stub.getState(pid);
		return resourceJSON && resourceJSON.length > 0;
	}
}

module.exports = ResourceEvents;
