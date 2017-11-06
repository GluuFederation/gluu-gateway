/**
 * Simple service to activate noty2 message to GUI. This service can be used every where in application. Generally
 * all $http and $socket queries uses this service to show specified errors to user.
 *
 * Service can be used as in following examples (assuming that you have inject this service to your controller):
 *  Message.success(message, [title], [options]);
 *  Message.error(message, [title], [options]);
 *  Message.message(message, [title], [options]);
 *
 * Feel free to be happy and code some awesome stuff!
 *
 * @todo do we need some queue dismiss?
 */
(function() {
  'use strict';

  angular.module('frontend.core.services')
    .factory('DialogService', [
      '$uibModal', '_',
      function factory($uibModal, _) {
        var service = {};



        service.prompt = function error(title,message, buttonTexts,accept, decline) {

          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            windowClass : 'dialog',
            template: '' +
            '<div class="modal-header dialog no-margin">' +
            '<h5 class="modal-title">' + title + '</h5>' +
            '</div>' +
            '<div class="modal-body">' + message + '</div>' +
            '<div class="modal-footer dialog">' +
            '<button class="btn btn-link" data-ng-click="decline()">' + buttonTexts[0] + '</button>' +
            '<button class="btn btn-success btn-link" data-ng-click="accept()">' + buttonTexts[1] + '</button>' +
            '</div>',
            controller: function($scope,$uibModalInstance){
                $scope.accept =  function() {
                  $uibModalInstance.dismiss('accept')
                }
                $scope.decline =  function(){
                  $uibModalInstance.dismiss('decline')
                }
            },
            size: 'sm'
          });

          modalInstance.result.then(function (d) {

          }, function (d) {
            switch(d){
              case "accept":
                accept()
                break;
              case "decline":
                decline()
                break;
            }
          });

        };




        return service;
      }
    ])
  ;
}());
