(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('OpenIDPluginController', [
      '_', '$scope', '$log', '$state', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'PluginHelperService', '_route', '_plugins', '$compile', 'InfoService', '$localStorage',
      function controller(_, $scope, $log, $state, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, PluginHelperService, _route, _plugins, $compile, InfoService, $localStorage) {
        $scope.globalInfo = $localStorage.credentials.user;
        $scope.route = (_route && _route.data) || null;
        $scope.upstream_url = '';
        $scope.plugins = _plugins.data.data;
        $scope.oauthPlugin = null;
        $scope.addNewScope = addNewScope;
        $scope.fetchData = fetchData;
        $scope.addPlugin = addPlugin;
        $scope.getDiscoveryResponse = getDiscoveryResponse;
        $scope.customHeaders = [['CUSTOM_NUMBER', '123321123']];
        $scope.claimSupported = [['role', '==', '[Mm][Aa]']];
        $scope.getKongProxyURL = getKongProxyURL;

        $scope.pluginConfig = {
          kong_proxy_url: '',
          oxd_url: $scope.globalInfo.oxdWeb,
          op_url: $scope.globalInfo.opHost,
          client_id: $scope.globalInfo.clientId,
          client_secret: $scope.globalInfo.clientSecret,
          authorization_redirect_path: '/callback',
          authorization_redirect_uri: '',
          logout_path: '/logout',
          post_logout_redirect_path_or_url: '/logout_redirect_uri',
          post_logout_redirect_uri: '',
          requested_scopes: ['openid', 'oxd', 'email', 'profile'],
          required_acrs: ['auth_ldap_server', 'u2f', 'otp'],
          max_id_token_age: 60,
          max_id_token_auth_age: 60
        };

        $scope.isPluginAdded = false;
        $scope.plugins.forEach(function (o) {
          if (o.name == "gluu-openid-connect") {
            // $scope.modelPlugin = o;
            // $scope.isPluginAdded = true;
          }
        });

        /**
         * ----------------------------------------------------------------------
         * Functions
         * ----------------------------------------------------------------------
         */
        function getKongProxyURL() {
          var route = $scope.route;
          var protocol = route.protocols.indexOf("https") < 0 ? "http": "https";
          var host = (route.hosts && route.hosts[0]) || "localhost";
          var path = (route.paths && route.paths[0]) || "";
          $scope.pluginConfig.kong_proxy_url = protocol + "://" + host;
          $scope.pluginConfig.authorization_redirect_path = path + "/callback";
          $scope.pluginConfig.post_logout_redirect_path_or_url = path + "/logout_redirect_uri";
          $scope.pluginConfig.logout_path = path + "/logout";
        }

        function fetchData() {
          InfoService
            .getInfo()
            .then(function (resp) {
              $scope.info = resp.data;
              $scope.upstream_url = "http://" + $scope.info.hostname + ":" + $scope.info.configuration.proxy_listeners[0].port;
              $log.debug("DashboardController:fetchData:info", $scope.info);
            })
        }

        function addNewScope(scope) {
          if ($scope.scopes_supported.indexOf(scope) > -1) {
            MessageService.error('Duplicate values not allowed!');
            return
          }
          $scope.scopes_supported.push(angular.copy(scope));
          $scope.newScope = ''
        }

        function getDiscoveryResponse() {
          $scope.loading = true;
          PluginsService
            .getOPDiscoveryResponse({op_url: $scope.pluginConfig.op_url})
            .then(function (opRes) {
              $scope.opResponse = opRes.data
            })
            .catch(function (error) {
              console.log(error);
              MessageService.error((error.data && error.data.message) || "Failed to get OP discovery response");
            })
            .finally(function () {
              $scope.loading = false;
            });
        }

        function addPlugin() {
          debugger
          var model = angular.copy($scope.pluginConfig);
          PluginsService
            .addOPClient({
              client_name: 'gg-openid-connect-client',
              op_host: model.op_url,
              oxd_url: model.oxd_url,
              authorization_redirect_uri: model.kong_proxy_url + model.authorization_redirect_path,
              post_logout_redirect_uri: model.kong_proxy_url + model.post_logout_redirect_path_or_url,
              scope: model.requested_scopes,
              acr_values: model.required_acrs
            })
            .then(function (response) {
              var opClient = response.data;
              var pluginModel = {
                name: 'gluu-openid-connect',
                route_id: $scope.route.id,
                config: {
                  oxd_id: opClient.oxd_id,
                  oxd_url: model.oxd_url,
                  client_id: opClient.client_id,
                  client_secret: opClient.client_secret,
                  op_url: model.op_url,
                  authorization_redirect_path: model.authorization_redirect_path,
                  logout_path: model.logout_path,
                  post_logout_redirect_path_or_url: model.post_logout_redirect_path_or_url,
                  requested_scopes: model.requested_scopes,
                  required_acrs: model.required_acrs,
                  max_id_token_age: model.max_id_token_age,
                  max_id_token_auth_age: model.max_id_token_auth_age,
                }
              };
              return new Promise(function (resolve, reject) {
                return PluginHelperService.addPlugin(
                  pluginModel,
                  function success(res) {
                    return resolve(res);
                  }, function (err) {
                    return reject(err);
                  });
              });
            })
            .then(function (res) {
              $state.go("routes");
              MessageService.success('Plugin added successfully!');
            })
            .catch(function (error) {
              $scope.busy = false;
              $log.error("create plugin", error);
              console.log(error);
              if (error.data.body) {
                Object.keys(error.data.body).forEach(function (key) {
                  MessageService.error(key + " : " + error.data.body[key]);
                });
                return
              }
              MessageService.error("Failed!");
            });
        }

        // init
        // $scope.fetchData();
        $scope.getDiscoveryResponse();
        $scope.getKongProxyURL();
      }
    ]);
}());