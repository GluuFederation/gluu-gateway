(function () {
  'use strict';

  angular.module('KongGUI.pages.api', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('api', {
        url: '/api',
        title: 'Register Resource',
        templateUrl: 'app/pages/api/api.html',
        controller: 'APIController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-navicon-round',
          order: 3
        }
      })
      .state('manageApi', {
        url: '/manageApi',
        templateUrl: 'app/pages/api/api.manage.modal.html',
        controller: 'ManageAPIController',
        controllerAs: '$ctrl',
        params: {
          oAPI: null
        }
      });
  }
})();
