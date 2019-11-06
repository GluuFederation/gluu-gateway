/**
 * This file contains all necessary Angular controller definitions for 'frontend.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.routes')
    .controller('RouteDetailsController', [
      '$scope', '$rootScope', '$log', '$state', 'RoutesService', 'MessageService', 'SettingsService', '_route',
      function controller($scope, $rootScope, $log, $state, RoutesService, MessageService, SettingsService, _route) {
        $scope.route = $scope.route || _route;
        $scope.settings = SettingsService.getSettings();
        $scope.addMoreHeader = addMoreHeader;
        var headers = $scope.route.headers;
        if (headers) {
          var bHeaders = [];
          $scope.route.bHeaders = bHeaders;
          for (var key in headers) {
            bHeaders.push({name: key, values: headers[key]})
          }
        }

        $scope.submit = function () {
          $scope.loading = true;

          if (!$scope.route.hosts) $scope.route.hosts = [];
          if (!$scope.route.paths) $scope.route.paths = [];
          if (!$scope.route.methods) $scope.route.methods = [];
          if (!$scope.route.protocols) $scope.route.protocols = [];

          var baseHeaders = $scope.route.bHeaders;
          if (baseHeaders && baseHeaders.length > 0) {
            var newHeader = {};
            baseHeaders.forEach(function (header) {
              newHeader[header.name] = header.values;
            });
            $scope.route.headers = newHeader;
          } else {
            $scope.route.headers = null
          }

          var route = angular.copy($scope.route);

          if (route.bHeaders) {
            delete route.bHeaders;
          }

          RoutesService.update(route.id, _.omit(route, ["id"]))
            .then(function (res) {
              $log.debug("Update Route: ", res);
              $scope.loading = false;
              MessageService.success('Route updated successfully!')
            }).catch(function (err) {
            console.log("err", err);
            $scope.loading = false;
            var errors = {};
            Object.keys(err.data.body).forEach(function (key) {
              MessageService.error(key + " : " + err.data.body[key])
            });
            $scope.errors = errors
          })
        }

        function addMoreHeader() {
          if (!$scope.route.bHeaders) {
            $scope.route.bHeaders = []
          }
          $scope.route.bHeaders.push({name: 'header1', values: ['v1']})
        }
      }
    ]);
}());
