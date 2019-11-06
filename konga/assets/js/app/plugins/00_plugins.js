(function () {
  'use strict';

  angular.module('frontend.plugins', []);

  // Module configuration
  angular.module('frontend.plugins')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
          .state('plugins', {
            parent: 'frontend',
            url: '/plugins',
            data: {
              activeNode: true,
              pageName: "Plugins",
              pageDescription: "A Plugin entity represents a plugin configuration that will be executed during the HTTP request/response workflow, and it's how you can add functionalities to APIs that run behind Kong, like Authentication or Rate Limiting for example.",
              //displayName : "plugins",
              prefix: '<i class="material-icons text-primary">settings_input_component</i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/plugins.html',
                controller: 'PluginsController'
              }
            }
          })
          .state('plugins.add', {
            url: '/add',
            params: {
              api: {}
            },
            data: {
              pageName: "Add Global Plugins",
              pageDescription: null,
              displayName: "add"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/add-plugins.html',
                controller: 'AddPluginsController',
                resolve: {
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {

                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            },
          })
          .state('plugins.oauth-plugin', {
            url: '/plugins/oauth-plugin',
            data: {
              pageName: "Gluu OAuth Auth & PEP",
              pageDescription: "This plugin enables the use of an external OpenID Provider for OAuth2 client registration and authentication. It needs to connect to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "Gluu OAuth plugins",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/oauth-plugin.html',
                controller: 'OAuthPluginController',
                resolve: {
                  _context_name: [
                    '$log',
                    function resolve() {
                      return null;
                    }
                  ],
                  _context_data: [
                    '$log',
                    function resolve() {
                      return null;
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.load()
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            }
          })
          .state('plugins.uma-plugin', {
            url: '/plugins/uma-plugin',
            data: {
              pageName: "Gluu UMA Auth & PEP",
              pageDescription: "This plugin enables the use of an external OpenID Provider for UMA resource registration and authorization. It needs to connect to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "Gluu UMA plugins",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/uma-plugin.html',
                controller: 'UMAPluginController',
                resolve: {
                  _context_name: [
                    '$log',
                    function resolve() {
                      return null;
                    }
                  ],
                  _context_data: [
                    '$log',
                    function resolve() {
                      return null
                    }
                  ],
                  _plugins: [
                    'PluginsService',
                    function resolve(PluginsService) {
                      return PluginsService.load()
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            }
          })
      }
    ]);
}());
