/**
 * Provides utility operations with LDAP entries.
 * 
 * Author: Meghna Joshi Date: 11/08/2013
 */

function EntryService(ldapClient) {
	this.ldapClient = ldapClient;
}

module.exports = EntryService;

EntryService.prototype.addEntryIfNotExist = function addEntryIfNotExist(dn, entry, callback) {
	var ldapClient = this.ldapClient;
	ldapClient.contains(dn, function(result) {
		if (result) {
			callback && callback();
		} else {
			ldapClient.add(dn, entry, function(result) {
				if (result) {
					console.log("Configuration. Added entry:'%s'", dn);
				} else {
					console.log("Configuration. Failed to add entry:'%s'", dn);
				}

				callback && callback();
			});
		}
	});
};
