(function () {
  'use strict';

  angular.module('KongGUI.pages.home', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('home', {
        url: '/home',
        title: 'Home',
        templateUrl: 'app/pages/home/home.html',
        controller: 'HomeController',
        controllerAs: '$ctrl',
        authenticate: true,
        sidebarMeta: {
          icon: 'ion-android-home',
          order: 0
        }
      });
  }
})();
