'use strict';

const ldap = require('../ldap/ldap-helper');

/**
 * Authentication Controller
 */
var ScopeController = {
  get: function (req, res) {
    ldap.scopeService.getAllScope(function (result) {
      return res.send(result);
    });
  },
};

module.exports = ScopeController;
