(function () {
  'use strict';

  angular.module('KongGUI.pages.umaRs')
    .controller('UMARsController', UMARsController);

  /** @ngInject */
  function UMARsController($scope, $filter, $state, toastr, umaRsService, apiService) {
    var vm = this;
    vm.modelPlugin = {
      name: "kong-uma-rs",
      config: {
        protection_document: [{
          path: "/path",
          conditions: [
            {
              httpMethods: [{text: "GET"}, {text: "POST"}],
              scopes: [
                {text: "http://example.com/dev/actions"}
              ],
              ticketScopes: []
            }]
        }]
      }
    };
    vm.apis = [];

    //Export the modules for view.
    vm.addPlugin = addPlugin;
    vm.getAPI = getAPI;
    vm.addNewPath = addNewPath;
    vm.addNewCondition = addNewCondition;
    vm.loadMethods = loadMethods;

    //init
    vm.getAPI();

    function addPlugin(isValid) {
      if (!isValid) {
        return false;
      }

      var model = angular.copy(vm.modelPlugin);
      model.config.protection_document.forEach(function (path, pIndex) {
        path.conditions.forEach(function (cond, cIndex) {
          cond.httpMethods = cond.httpMethods.map(function (o) {
            return o.text;
          });
          cond.scopes = cond.scopes.map(function (o) {
            return o.text;
          });
          if (cond.ticketScopes.length > 0) {
            cond.ticketScopes = cond.ticketScopes.map(function (o) {
              return o.text;
            });
          } else {
            delete cond.ticketScopes;
          }
        });
      });

      model.config.protection_document = (JSON.stringify(JSON.parse(angular.toJson(model.config.protection_document))));

      umaRsService.addPlugin(vm.api_id, model, onSuccess, onError);
      function onSuccess(response) {
        toastr.success('Saved successfully', 'Plugin', {});
        $state.go('api');
      }

      function onError(error) {
        toastr.error(error.data.message, 'Plugin', {})
      }
    }

    function getAPI() {
      apiService.getAPI(onSuccess, onError);
      function onSuccess(response) {
        if (response.data && response.data.total > 0) {
          vm.apis = response.data.data;
        }
      }

      function onError(error) {
        toastr.error(error.data.message, 'Plugin', {})
      }
    }

    function addNewPath() {
      vm.modelPlugin.config.protection_document.push({
        path: "/path",
        conditions: [
          {
            httpMethods: [{text: "GET"}],
            scopes: [
              {text: "http://example.com/view"}
            ],
            ticketScopes: []
          }
        ]
      });
    }

    function addNewCondition(pathIndex) {
      vm.modelPlugin.config.protection_document[pathIndex].conditions.push(
        {
          httpMethods: [{text: "GET"}],
          scopes: [
            {text: "http://example.com/view"}
          ],
          ticketScopes: []
        });
    }

    function loadMethods() {
      return ['GET', 'POST', 'DELETE', 'PUT', 'PATCH'];
    }
  }
})();
