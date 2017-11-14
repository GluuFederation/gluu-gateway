/**
 * Provides LDAP operations with devices.
 *
 * Author: Meghna Joshi Date: 15/09/2017
 */
var util = require('util');
const random = require('randomstring');
function ScopeService(ldapClient) {
  this.ldapClient = ldapClient;
}

module.exports = ScopeService;

ScopeService.prototype.getAllScope = function containsScopeId(callback) {
  var scopeDn = this.ldapClient.getDn('ou=scopes,ou=uma');
  this.ldapClient.search(scopeDn, '&(objectClass=oxAuthUmaScopeDescription)', [], 'sub', 0,
    function (entries) {
      if (entries == null) {
        return callback && callback(null);
      }
      return callback(entries);
    });
};

ScopeService.prototype.updateScope = function updateScope(scope, callback) {

  if (scope.scopeInums.length <= 0) {
    return callback({msg: "Success"});
  }

  var scriptDn = '';

  if (!!scope.scriptInum) {
    scriptDn = this.ldapClient.getDn('ou=scripts', 'inum=' + scope.scriptInum);
  } else {
    scriptDn = ''
  }


  var attrs = {
    oxPolicyScriptDn: scriptDn,
  };

  var cnt = 0;

  scope.scopeInums.forEach(function (inum) {
    var scopeDn = this.ldapClient.getDn('ou=scopes,ou=uma', 'inum=' + inum);
    this.ldapClient.modify(scopeDn, 'replace', attrs, function (result) {
      cnt++;
      if (cnt == scope.scopeInums.length) {
        callback && callback(result);
      }
    });
  });
};

ScopeService.prototype.addScope = function addScope(scopes, callback) {
  var that = this;
  _addScope(scopes, this)
    .then(function (scopes) {
      if (scopes.length <= 0) {
        callback(false);
      }

      scopes = scopes.map(function (inum) {
        return that.ldapClient.getDn('ou=scopes,ou=uma', 'inum=' + inum);
      });
      var oxdId = getLowerRandom(8) + "-" + getLowerRandom(4) + "-" + getLowerRandom(4) + "-" + getLowerRandom(4) + +"-" + getLowerRandom(12);
      var resourceDn = that.ldapClient.getDn('ou=resources,ou=uma', 'oxId=' + oxdId);
      var attrs = {
        oxId: oxdId,
        displayName: "[GET] /about",
        oxAssociatedClient: that.ldapClient.getDn('ou=clients', 'inum=' + sails.config.ldapClientId),
        oxAuthUmaScope: scopes,
        objectClass: ['top', 'oxUmaResource'],
        oxRevision: '1'
      };
      that.ldapClient.add(resourceDn, attrs, function (result) {
        callback(result);
      });
    });
};

function _addScope(scopes, client) {
  return new Promise(function (resolve, reject) {
    var scopeDn = client.ldapClient.getDn('ou=scopes,ou=uma');
    var that = this;
    client.ldapClient.search(scopeDn, '&(objectClass=oxAuthUmaScopeDescription)', [], 'sub', 0,
      function (entries) {
        if (entries == null) {
          return resolve([]);
        }
        scopes = scopes.filter(function (item, pos) {
          return scopes.indexOf(item) == pos;
        });

        entries = entries.map(function (o) {
          return o.oxId;
        });

        scopes = scopes.filter(function (o) {
          return entries.indexOf(o) < 0;
        });

        if (scopes.length <= 0) {
          return resolve([]);
        }

        var cnt = 0;
        var arr = [];
        scopes.forEach(function (scope) {
          var inum = sails.config.ldapClientId + "!" + getUpperRandom(4) + "." + getUpperRandom(4) + "." + getUpperRandom(4) + "." + getUpperRandom(4);
          var scriptDn = client.ldapClient.getDn('ou=scopes,ou=uma', 'inum=' + inum);
          var attrs = {
            inum: inum,
            displayName: scope,
            oxId: scope,
            objectClass: ['top', 'oxAuthUmaScopeDescription']
          };

          client.ldapClient.add(scriptDn, attrs, function (result) {
            arr.push(inum);
            cnt++;
            if (cnt == scopes.length) {
              return resolve(arr);
            }
          });
        });
      });
  });
}

function getUpperRandom(length) {
  return random.generate({length: length, charset: 'alphanumeric', capitalization: 'uppercase'});
}

function getLowerRandom(length) {
  return random.generate({length: length, charset: 'alphanumeric', capitalization: 'lowercase'});
}