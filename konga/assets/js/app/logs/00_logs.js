(function () {
  'use strict';

  angular.module('frontend.logs', []);

  // Module configuration
  angular.module('frontend.logs')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
          .state('logs', {
            url: '/logs',
            parent: 'frontend',
            cache: false,
            data: {
              pageName: "Audit Logs",
              pageDescription: "OIDC Plugin change logs"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/logs/index.html',
                controller: 'LogsController',
                resolve: {
                  _items: [
                    'ListConfig',
                    'LogModel',
                    function resolve(ListConfig,
                                     LogModel) {
                      var config = ListConfig.getConfig();

                      var parameters = {
                        limit: config.itemsPerPage,
                        sort: 'createdAt DESC'
                      };

                      return LogModel.load(parameters);
                    }
                  ],
                  _count: [
                    'LogModel',
                    function resolve(LogModel) {
                      return LogModel.count();
                    }
                  ]
                }
              }
            }
          })
      }
    ]);
}());
