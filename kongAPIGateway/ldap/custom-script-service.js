/**
 * Provides LDAP operations with devices.
 *
 * Author: Meghna Joshi Date: 15/09/2017
 */
var util = require('util');
function CustomScriptService(ldapClient) {
  this.ldapClient = ldapClient;
}

module.exports = CustomScriptService;

CustomScriptService.prototype.getAllCustomScript = function containsCustomScriptId(callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts');
  this.ldapClient.search(scriptDn, '&(objectClass=oxCustomScript)(oxScriptType=' + process.env.SCRIPT_TYPE + ')', [], 'sub', 0,
    function (entries) {
      if (entries == null) {
        return callback && callback(null);
      }
      return callback(entries);
    });
};

CustomScriptService.prototype.containsCustomScriptId = function containsCustomScriptId(inum, callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + inum);
  this.ldapClient.contains(scriptDn, function (result) {
    callback && callback(result);
  });
};

CustomScriptService.prototype.getCustomScriptById = function getCustomScriptById(inum, callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + inum);
  this.ldapClient.get(scriptDn, function (entry) {
    callback && callback(entry);
  });
};

CustomScriptService.prototype.deleteCustomScript = function deleteCustomScript(inum, callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + inum);
  this.ldapClient.del(scriptDn, function (entry) {
    callback && callback(entry);
  });
};

CustomScriptService.prototype.addCustomScript = function addCustomScript(script, callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + script.inum);
  var attrs = {
    inum: script.inum,
    description: script.description,
    displayName: script.displayName,
    gluuStatus: script.gluuStatus,
    oxConfigurationProperty: script.oxConfigurationProperty,
    oxLevel: script.oxLevel,
    oxModuleProperty: script.oxModuleProperty,
    oxRevision: script.oxRevision,
    oxScript: script.oxScript,
    oxScriptType: script.oxScriptType,
    programmingLanguage: script.programmingLanguage,
    objectClass: ['top', 'oxCustomScript']
  };

  Object.keys(attrs).forEach(function (key) {
    if (typeof attrs[key] === 'undefined') {
      delete attrs[key];
    }
  });
  this.ldapClient.add(scriptDn, attrs, function (result) {
    callback && callback(result);
  });
};

CustomScriptService.prototype.updateCustomScript = function updateCustomScript(script, callback) {
  var scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + script.inum);
  var attrs = {
    description: script.description,
    displayName: script.displayName,
    oxConfigurationProperty: script.oxConfigurationProperty,
    oxScript: script.oxScript,
    gluuStatus: script.gluuStatus,
  };

  Object.keys(attrs).forEach(function (key) {
    if (typeof attrs[key] === 'undefined') {
      delete attrs[key];
    }
  });

  this.ldapClient.modify(scriptDn, 'replace', attrs, function (result) {
    callback && callback(result);
  });
};