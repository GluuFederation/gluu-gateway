const express = require('express');
const random = require('randomstring');
const router = express.Router();

const ldap = require('../ldap/ldap-helper');

router.get('/scopes', (req, res) => {
  ldap.scopeService.getAllScope(function (result) {
    return res.send(result);
  });
});

router.post('/scopes', (req, res) => {
  ldap.scopeService.updateScope(req.body, function (result) {
    return res.send(result);
  });
});

router.get('/scopes/add', (req, res) => {
  ldap.scopeService.addScope(["http://test.com/about", "http://test2.com/about"], function (result) {
    return res.send({msg: result});
  });
});

module.exports = router;