(function () {
  'use strict';

  angular.module('KongGUI.pages.home')
    .controller('HomeController', HomeController);

  /** @ngInject */
  function HomeController($http, toastr, $uibModal, $timeout) {
    var vm = this;
    vm.plugin = "Kong";
  }
})();
