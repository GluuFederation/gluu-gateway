/**
 * @author v.lugovsky
 * created on 10.12.2016
 */
(function () {
  'use strict';

  angular.module('KongGUI.theme.inputs')
      .directive('baSwitcher', baSwitcher);

  /** @ngInject */
  function baSwitcher() {
    return {
      templateUrl: 'app/theme/inputs/baSwitcher/baSwitcher.html',
      scope: {
        switcherStyle: '@',
        switcherValue: '='
      }
    };
  }

})();
