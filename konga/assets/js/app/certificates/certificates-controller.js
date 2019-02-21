/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.certificates')
    .controller('CertificatesController', [
      '$scope', '$rootScope', '$log', '$state', '$uibModal', 'DialogService', 'UserService',
      'MessageService', 'SettingsService', '$http', 'Upload', 'Semver', '$timeout', 'CertificateModel', 'ListConfig',
      function controller($scope, $rootScope, $log, $state, $uibModal, DialogService, UserService,
                          MessageService, SettingsService, $http, Upload, Semver, $timeout, CertificateModel, ListConfig) {

        CertificateModel.setScope($scope, false, 'items', 'itemCount');
        $scope = angular.extend($scope, angular.copy(ListConfig.getConfig('certificate', CertificateModel)));
        $scope.user = UserService.user();

        $scope.openUploadCertsModal = function (certificate) {
          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/certificates/add-certificates-modal.html',
            controller: function ($scope, $uibModal, $uibModalInstance, SnisModel, DialogService, _certificate) {
              $scope.update = _certificate;
              $scope.data = _certificate || {};
              $scope.close = function () {
                return $uibModalInstance.dismiss()
              };

              $scope.deleteSNI = function (sni) {
                DialogService.prompt(
                  "Confirm", "Really want to delete the selected item?",
                  ['No don\'t', 'Yes! delete it'],
                  function accept() {
                    SnisModel.delete(sni)
                      .then(function (res) {
                        $scope.data.snis.splice($scope.data.snis.indexOf(sni), 1);
                      }, function (err) {
                        $log.error("ListConfigService : Model delete failed => ", err)
                      });
                  }, function decline() {
                  })
              };


              $scope.openAddSniModal = function () {
                var modalInstance = $uibModal.open({
                  animation: true,
                  ariaLabelledBy: 'modal-title',
                  ariaDescribedBy: 'modal-body',
                  templateUrl: 'js/app/certificates/add-sni-modal.html',
                  size: 'sm',
                  controller: function ($scope, $uibModalInstance, SnisModel, DialogService, _certId) {
                    $scope.close = function () {
                      return $uibModalInstance.dismiss();
                    };

                    $scope.submit = function () {
                      var data = {
                        name: $scope.sni,
                        ssl_certificate_id: _certId
                      };

                      data.certificate = {
                        id: _certId
                      };
                      delete data.ssl_certificate_id;

                      SnisModel.create(data).then(function (created) {
                        $uibModalInstance.close({
                          data: created.data.name
                        });
                      }).catch(function (err) {
                        console.error("Failed to create SNI =>", err);
                        SnisModel.handleError($scope, err);
                      });
                    };
                  },
                  resolve: {
                    _certId: function () {
                      return _certificate.id;
                    }
                  }

                });

                modalInstance.result.then(function (data) {
                  if (data && data.data) $scope.data.snis.push(data.data);
                }, function (data) {
                });
              };


              $scope.submitCerts = function () {

                $scope.errorMessage = "";


                var data = angular.copy($scope.data);

                if (!data.cert || !data.key) {
                  $scope.errorMessage = "The `Certificate` and/or `Key` fields cannot be empty"
                  return false;
                }

                data.cert = data.cert.trim();
                data.key = data.key.trim();

                if (data.snis) {
                  data.snis = data.snis.split(",")
                }

                CertificateModel.create(data)
                  .then(function (resp) {
                    console.log('Success', resp.data);
                    $uibModalInstance.dismiss({
                      data: resp
                    })
                  }).catch(function (err) {
                  console.error('Error', err);
                  handleErrors(err)
                })
              };

              $scope.updateCerts = function () {

                $scope.errorMessage = "";

                var data = angular.copy($scope.data);

                if (!data.cert || !data.key) {
                  $scope.errorMessage = "The `Certificate` and/or `Key` fields cannot be empty"
                  return false;
                }

                data.cert = data.cert.trim();
                data.key = data.key.trim();

                CertificateModel.update(data.id, _.omit(data, ['id']))
                  .then(function (resp) {
                    console.log('Success', resp.data);
                    $uibModalInstance.dismiss({
                      data: resp
                    })
                  }).catch(function (err) {
                  console.error('Error', err);
                  handleErrors(err)
                })
              };

              function handleErrors(err) {
                $scope.errors = {};

                if (err.data) {
                  if (err.data.customMessage) {

                    for (var key in err.data.customMessage) {
                      $scope.errors[key] = err.data.customMessage[key]
                    }
                  }

                  if (err.data.message) {
                    $scope.errorMessage = err.data.message
                  }
                } else {
                  $scope.errorMessage = "An unknown error has occured"
                }
              }
            },
            controllerAs: '$ctrl',
            resolve: {
              _certificate: function () {
                return certificate
              }
            }
          });

          modalInstance.result.then(function () {
          }, function (data) {
            if (data && data.data) _fetchData()
          });
        };

        function _fetchData() {
          $scope.loading = true;
          CertificateModel.load({
            size: $scope.itemsFetchSize
          }).then(function (response) {
            console.log(response);
            $scope.items = response;
            $scope.loading = false;

            if (response.data && Object.keys(response.data).length) {
              $scope.certificates = Semver.cmp($rootScope.Gateway.version, "0.10.1") > 0 ? response.data.data : response.data
            } else {
              $scope.certificates = []
            }
          })
        }

        _fetchData();

        $scope.$on('user.node.updated', function (node) {
          $timeout(function () {
            _fetchData()
          })
        })
      }
    ]);
}());
