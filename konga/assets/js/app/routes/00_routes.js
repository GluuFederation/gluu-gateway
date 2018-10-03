(function () {
  'use strict';

  angular.module('frontend.routes', [
    'angular.chips',
    'ngFileUpload'
  ]);

  // Module configuration
  angular.module('frontend.routes')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
          .state('routes', {
            parent: 'frontend',
            url: '/routes',
            data: {
              activeNode: true,
              pageName: "Routes",
              pageDescription: "" +
              "The Route entities defines rules to match client requests. Each Route is associated with a Service, and a Service may have multiple Routes associated to it. Every request matching a given Route will be proxied to its associated Service.",
              //displayName : "routes",
              prefix: '<i class="material-icons">cloud_queue</i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/routes.html',
                controller: 'RoutesController',
                resolve: {
                  _services: [
                    'ServiceModel', function resolve(ServiceModel) {
                      return ServiceModel.load({
                        size: 4294967295
                      })
                    }
                  ]
                }
              }
            }
          })
          .state('routes.edit', {
            url: '/:route_id/edit',
            data: {
              pageName: "Edit Route",
              pageDescription: "",
              displayName: "edit Route",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/edit-route.html',
                controller: 'RouteController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function resolve(RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }

              },
              'details@routes.edit': {
                templateUrl: 'js/app/routes/views/route-details.html',
                controller: 'RouteDetailsController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function resolve(RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ]
                }
              },
              'plugins@routes.edit': {
                templateUrl: 'js/app/routes/views/route-plugins.html',
                controller: 'RoutePluginsController',
                resolve: {
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.load({route_id: $stateParams.route_id})
                    }
                  ]
                }
              },
              'consumers@routes.edit': {
                templateUrl: 'js/app/routes/views/route-consumers.html',
                controller: 'RouteConsumersController'
              }
            }
          })
          .state('routes.oauth-plugin', {
            url: '/:route_id/oauth-plugin',
            data: {
              pageName: "OAuth plugin",
              pageDescription: "This plugin enables the use of an external OpenID Provider for OAuth2 client registration and authentication. It needs to connect via `https` to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "OAuth plugin",
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
                      return 'route';
                    }
                  ],
                  _context_data: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.load({route_id: $stateParams.route_id})
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
          .state('routes.uma-plugin', {
            url: '/:route_id/uma-plugin',
            data: {
              pageName: "UMA plugin",
              pageDescription: "This plugin enables the use of an external OpenID Provider for UMA resource registration and authorization. It needs to connect to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "UMA plugin",
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
                      return 'route';
                    }
                  ],
                  _context_data: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.load({route_id: $stateParams.route_id})
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
          .state('routes.plugins', {
            url: '/:route_id/plugins',
            params: {
              route: {}
            },
            data: {
              pageName: "Route Plugins",
              displayName: "Route plugins"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/route-plugins.html',
                controller: 'RoutePluginsController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function (RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.load({
                        route_id: $stateParams.route_id
                      })
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
            },
          })
          .state('routes.plugins.manage', {
            url: '/manage',
            data: {
              pageName: "Manage Route Plugins",
              displayName: "manage"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/plugins/manage/manage-route-plugins.html',
                controller: 'ManageRoutePluginsController',
                resolve: {
                  _route: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService,
                                     $log) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService,
                                     $log) {
                      return RoutesService.plugins($stateParams.route_id)
                    }
                  ],
                  _info: [
                    '$stateParams',
                    'InfoService',
                    '$log',
                    function resolve($stateParams,
                                     InfoService,
                                     $log) {
                      return InfoService.getInfo()
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
            },
          })
      }
    ])
  ;
}());
