(function () {
  'use strict';

  angular.module('KongGUI.pages.umaScript', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('umaScript', {
        url: '/umaScript',
        title: 'UMA Script',
        templateUrl: 'app/pages/umaScript/umaScript.html',
        controller: 'UMAScriptController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-locked',
          order: 3
        }
      });
  }
})();
