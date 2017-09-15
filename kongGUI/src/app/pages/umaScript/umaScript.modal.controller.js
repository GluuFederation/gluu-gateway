(function () {
  'use strict';

  angular.module('KongGUI.pages.umaScript')
    .controller('UMAScriptManageController', UMAScriptManageController);

  /** @ngInject */
  function UMAScriptManageController($uibModalInstance, scriptData, toastr, umaScriptService) {
    var vm = this;
    var counter = 0;

    if (!!scriptData) {
      vm.model = {
        inum: scriptData.inum,
        name: scriptData.displayName,
        description: scriptData.description,
        keyValues: JSON.parse(scriptData.oxConfigurationProperty)
      };

      vm.model.keyValues.forEach(o => {
        o.claimDefinition = JSON.stringify(o.claimDefinition)
      });
    } else {
      vm.model = {
        name: '',
        description: '',
        keyValues: [{
          id: counter, key: 'country', value: 'US', claimDefinition: `{
            "issuer" : [ "%1$s" ],
            "name" : "country",
            "claim_token_format" : [ "http://openid.net/specs/openid-connect-core-1_0.html#IDToken" ],
            "claim_type" : "string",
            "friendly_name" : "country"
        }`
        }]
      };
    }

    //Export the modules for view.
    vm.manageScript = manageScript;
    vm.newItem = newItem;

    // definition
    function newItem() {
      counter++;
      vm.model.keyValues.push({id: counter, key: '', value: ''});
    }

    function manageScript(isValid) {
      if (!isValid) {
        return false;
      }

      if (!!vm.model.inum) {
        umaScriptService.updateScript(vm.model.inum, vm.model, onSuccess, onError);
      } else {
        umaScriptService.addScript(vm.model, onSuccess, onError);
      }

      function onSuccess(response) {
        toastr.success('Saved successfully', 'Script', {});
        $uibModalInstance.close(response.data);
      }

      function onError(error) {
        toastr.error('Failed', 'Script', {})
      }
    }
  }
})();
