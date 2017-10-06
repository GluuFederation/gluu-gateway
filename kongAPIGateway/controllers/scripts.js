const express = require('express');
const random = require('randomstring');
const router = express.Router();

const ldap = require('../ldap/ldap-helper');
const common = require('../helper/common');

router.get('/scripts/:inum', (req, res) => {
  ldap.customScriptService.getCustomScriptById(req.params.inum, function (result) {
    return res.send(result);
  });
});

router.get('/scripts', (req, res) => {
  ldap.customScriptService.getAllCustomScript(function (result) {
    return res.send(result);
  });
});

router.post('/scripts', (req, res) => {

  req.body.keyValues.forEach(o => {
    o.claimDefinition = (JSON.parse(o.claimDefinition))
  });

  const script = {
    inum: process.env.LDAP_CLIENT_ID + "!" + random.generate(4) + "." + random.generate(4),
    description: req.body.description || '',
    displayName: req.body.name || '',
    oxScript: common.umaScript,
    oxScriptType: process.env.SCRIPT_TYPE,
    programmingLanguage: 'python',
    oxConfigurationProperty: [],
    gluuStatus: req.body.status,
    oxLevel: '0',
    oxRevision: '1',
    oxModuleProperty: '{"value1":"location_type","value2":"ldap","description":""}'
  };

  var condition = '';
  var claimDefinition = '';

  req.body.keyValues.forEach(o => {
    condition += `context.getClaim("${o.key}") == '${o.value}' and `;
    claimDefinition += `${JSON.stringify(o.claimDefinition)},`;
    script.oxConfigurationProperty.push(`${JSON.stringify(o)}`);
  });

  if (script.oxConfigurationProperty.length == 1) {
    script.oxConfigurationProperty = script.oxConfigurationProperty[0]
  }

  condition = condition.substr(0, condition.length - 5);
  claimDefinition = claimDefinition.substr(0, claimDefinition.length - 1);

  script.oxScript = script.oxScript.replace('%s%', condition);
  script.oxScript = script.oxScript.replace('%c%', claimDefinition);
  ldap.customScriptService.addCustomScript(script, function (result) {
    return res.send({result: result});
  });
});

router.delete('/scripts/:inum', (req, res) => {
  ldap.customScriptService.deleteCustomScript(req.params.inum, function (result) {
    return res.send({result: result});
  });
});

router.put('/scripts/:inum', (req, res) => {

  req.body.keyValues.forEach(o => {
    o.claimDefinition = (JSON.parse(o.claimDefinition))
  });

  const script = {
    inum: req.params.inum,
    description: req.body.description || '',
    displayName: req.body.name || '',
    oxScript: common.umaScript,
    oxScriptType: process.env.SCRIPT_TYPE,
    programmingLanguage: 'python',
    oxConfigurationProperty: [],
    gluuStatus: req.body.status,
    oxLevel: '0',
    oxRevision: '1'
  };

  var condition = '';
  var claimDefinition = '';

  req.body.keyValues.forEach(o => {
    condition += `context.getClaim("${o.key}") == '${o.value}' and `;
    claimDefinition += `${JSON.stringify(o.claimDefinition)},`;
    script.oxConfigurationProperty.push(`${JSON.stringify(o)}`);
  });

  if (script.oxConfigurationProperty.length == 1) {
    script.oxConfigurationProperty = script.oxConfigurationProperty[0]
  }

  condition = condition.substr(0, condition.length - 5);
  claimDefinition = claimDefinition.substr(0, claimDefinition.length - 1);

  script.oxScript = script.oxScript.replace('%s%', condition);
  script.oxScript = script.oxScript.replace('%c%', claimDefinition);
  ldap.customScriptService.updateCustomScript(script, function (result) {
    return res.send({result: result});
  });
});

module.exports = router;