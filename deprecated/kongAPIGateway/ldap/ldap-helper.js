/**
 * Ldap helper.
 *
 * Author: Meghna Joshi Date: 15/09/2017
 */

var async = require('async');
var EntryService = require('./entry-service');
var LdapClient = require('./client');
var CustomScriptService = require('./custom-script-service');
var ScopeService = require('./scope-service');

var BASE_DN = 'o=' + process.env.LDAP_CLIENT_ID + ',o=gluu';
if (!BASE_DN) {
  throw new Error("LDAP_BASE_DN environment variable isn't set!");
}

var ldapClient = new LdapClient(BASE_DN);
var entryService = new EntryService(ldapClient);

module.exports = {
  ldapClient: ldapClient,
  entryService: entryService,
  customScriptService: new CustomScriptService(ldapClient),
  scopeService: new ScopeService(ldapClient),
  prepareDefaultEntires: prepareDefaultEntires,
};

function prepareDefaultEntires(callback) {
  if (typeof (callback) !== 'function') {
    throw new TypeError('Callback (function) required');
  }

  async.series([function (done) {
    var baseDn = ldapClient.getDn('', 'ou=people');

    var entry = {
      ou: 'push',
      objectclass: ['top', 'organizationalUnit']
    };

    entryService.addEntryIfNotExist(baseDn, entry, done);
  }
  ]);
}
