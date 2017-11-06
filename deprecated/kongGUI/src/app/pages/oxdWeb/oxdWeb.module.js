(function () {
  'use strict';

  angular.module('KongGUI.pages.oxdWeb', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('oxdweb', {
        url: '/oxdweb',
        title: 'OXD Web',
        templateUrl: 'app/pages/oxdWeb/oxdWeb.html',
        controller: 'OXDWebController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-navicon-round',
          order: 5
        }
      });
  }
})();
