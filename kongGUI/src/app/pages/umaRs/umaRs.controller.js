(function () {
  'use strict';

  angular.module('KongGUI.pages.umaRs')
    .controller('UMARsController', UMARsController);

  /** @ngInject */
  function UMARsController($scope, $filter, $state, toastr, umaRsService, apiService, umaScriptService) {
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
    vm.scopes = [];

    //Export the modules for view.
    vm.addPlugin = addPlugin;
    vm.getAPI = getAPI;
    vm.addNewPath = addNewPath;
    vm.addNewCondition = addNewCondition;
    vm.loadMethods = loadMethods;
    vm.loadScopes = loadScopes;

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

    function loadMethods(query) {
      var arr = ['GET', 'POST', 'DELETE', 'PUT', 'PATCH'];
      arr = arr.filter(function (o) {
        return o.indexOf(query.toUpperCase()) >= 0;
      });
      return arr;
    }

    function loadScopes(query) {
      //return vm.scopes;
      return umaScriptService.getScope(onSuccess, onError);

      function onSuccess(response) {
        vm.scopes = response.data.map(function (o) {
          return {text: o.oxId, name: o.displayName};
        });
        vm.scopes = vm.scopes.filter(function (o) {
          return o.name.indexOf(query) >= 0;
        });

        return vm.scopes;
      }

      function onError(error) {
        toastr.error('Failed to fetch scope', 'Scope', {})
      }
    }
  }
})();
