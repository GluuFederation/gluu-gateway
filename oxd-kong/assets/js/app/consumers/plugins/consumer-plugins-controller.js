/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function() {
  'use strict';

  angular.module('frontend.consumers')
    .controller('ConsumerPluginsController', [
      '_','$scope', '$stateParams','$log', '$state','$uibModal','ConsumerService','PluginsService','MessageService','DialogService',
      function controller(_,$scope,$stateParams, $log, $state, $uibModal,ConsumerService,PluginsService, MessageService,DialogService) {


          $scope.onAddPlugin = onAddPlugin
          $scope.onEditPlugin = onEditPlugin
          $scope.deletePlugin = deletePlugin
          $scope.updatePlugin = updatePlugin
          $scope.search = ''


          /**
           * ----------------------------------------------------------------------
           * Functions
           * ----------------------------------------------------------------------
           */

          function onAddPlugin() {
              $uibModal.open({
                  animation: true,
                  ariaLabelledBy: 'modal-title',
                  ariaDescribedBy: 'modal-body',
                  templateUrl: 'js/app/plugins/modals/add-consumer-plugin-modal.html',
                  size : 'lg',
                  controller: 'AddPluginModalController',
                  resolve: {
                      _consumer: function () {
                          return $scope.consumer;
                      },
                      _api : function() {
                        return null;
                      },
                      _plugins : function() {
                          return PluginsService.load();
                      },
                      _info: [
                          '$stateParams',
                          'InfoService',
                          '$log',
                          function resolve(
                              $stateParams,
                              InfoService,
                              $log
                          ) {
                              return InfoService.getInfo();
                          }
                      ]
                  }
              });
          }

          function updatePlugin(plugin) {
              PluginsService.update(plugin.id,{
                  enabled : plugin.enabled,
                  //config : plugin.config
              })
                  .then(function(res){
                      $log.debug("updatePlugin",res)
                      $scope.plugins.data[$scope.plugins.data.indexOf(plugin)] = res.data;

                  }).catch(function(err){
                  $log.error("updatePlugin",err);
              });
          }


          function deletePlugin(plugin) {
              DialogService.prompt(
                  "Delete Plugin","Really want to delete the plugin?",
                  ['No don\'t','Yes! delete it'],
                  function accept(){
                      PluginsService.delete(plugin.id)
                          .then(function(resp){
                              $scope.plugins.data.splice($scope.plugins.data.indexOf(plugin),1);
                          }).catch(function(err){
                          $log.error(err)
                      })
                  },function decline(){})
          }

          function onEditPlugin(item) {
              $uibModal.open({
                  animation: true,
                  ariaLabelledBy: 'modal-title',
                  ariaDescribedBy: 'modal-body',
                  templateUrl: 'js/app/plugins/modals/edit-plugin-modal.html',
                  size : 'lg',
                  controller: 'EditPluginController',
                  resolve: {
                      _plugin: function () {
                          return _.cloneDeep(item);
                      },
                      _schema: function () {
                          return PluginsService.schema(item.name);
                      }
                  }
              });
          }




          function fetchPlugins() {
              ConsumerService.listPlugins($stateParams.id)
                  .then(function(res){
                      $scope.plugins = res.data;
                  });
          }

          fetchPlugins();


          /**
           * ------------------------------------------------------------
           * Listeners
           * ------------------------------------------------------------
           */
          $scope.$on("plugin.added",function(){
              fetchPlugins();
          });

          $scope.$on("plugin.updated",function(ev,plugin){
              fetchPlugins();
          });

      }
    ]);
}());
