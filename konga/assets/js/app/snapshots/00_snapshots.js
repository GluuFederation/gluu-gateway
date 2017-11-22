
(function() {
    'use strict';

    angular.module('frontend.snapshots', [
    ]);

    // Module configuration
    angular.module('frontend.snapshots')
        .config([
            '$stateProvider',
            function config($stateProvider) {
                $stateProvider
                    .state('snapshots', {
                        url: '/snapshots',
                        parent : 'frontend',
                        data : {
                            access : 0,
                            pageName : "Snapshots",
                            pageDescription : "Take snapshots of currently active nodes.<br>All <code>APIs</code>, <code>Plugins</code>, <code>Consumers</code>, <code>Upstreams</code> and <code>Targets</code>will be saved and available for later import.",
                            prefix : '<i class="mdi mdi-camera"></i>'
                        },
                        views: {
                            'content@': {
                                templateUrl: 'js/app/snapshots/index.html',
                                    controller: 'SnapshotsController'
                            },

                        }
                    })
                    .state('snapshots.show', {
                        url: '/:id',
                        parent : 'snapshots',
                        data : {
                            access : 0,
                            pageName : "Snapshot Details",
                            displayName : "snapshot details",
                            pageDescription : null,
                            prefix : '<i class="mdi mdi-36px mdi-camera"></i>'
                        },
                        views: {
                            'content@': {
                                templateUrl: 'js/app/snapshots/snapshot.html',
                                controller: 'SnapshotController',
                                // resolve : {
                                //     _snapshot : ['Snapshot','$stateParams',
                                //         function(Snapshot,$stateParams){
                                //             return Snapshot.fetch($stateParams.id)
                                //         }]
                                // }
                            },
                        }
                    })
            }
        ])
    ;
}());
