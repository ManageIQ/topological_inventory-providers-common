# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.3] - 2020-12-14
Update travis URL in README file #67
Kafka availability_checks fix #68

## [2.1.2] - 2020-11-24
Custom Metrics for AsyncWorker #60
Change error metric name to errors_total #64

## [2.1.1] - 2020-11-04
MessagingClient and Source fix #61
Fix availability_check in app check #62

## [2.1.0] - 2020-11-02
Add Availability checks for sources via Kafka #54
Common Metrics exporter #57
Rubocop rules from insights-api-common + yamllint #59

## [2.0.0] - 2020-10-20
Operations/API clients refactoring

## [1.0.12] - 2020-10-05
Add Operations Async Worker class #55

## [1.0.11] - 2020-09-04
Make Collector Poll Time a parameter so we can tweak the collection interval #51

## [1.0.10] - 2020-08-26
Add HealthCheck class for operations workers #48
Set the LOG_LEVEL if present #50

## [1.0.9] - 2020-08-17
Added refresh-type to save and sweep inventory #45

## [1.0.8] - 2020-08-12
Add => to error messages that rubocop missed #44

## [1.0.7] - 2020-07-27
Update operations/source model for receptor-enabled availability checks #36
Add check for Application subresource under a Source during Availability check #40
Remove infinite loop in error messages #43

## [1.0.6] - 2020-07-06
Add some error handling if Sources does not have endpoints/authentications for a source #38
Specs for Collector #35

## [1.0.5] - 2020-06-18
Change release workflow to do everything manually #32
Add specs to released files #33

## [1.0.4] - 2020-06-18
Common availability check operation #25
Rubocop and codecoverage #29
Add github workflow to release to rubygems automatically #31

## [1.0.3] - 2020-06-04
### Changed

Bump Sources API client to 3.0 #26

## [1.0.2] - 2020-05-15
### Changed

Extend logger with common logging phrases #22
Security update: JSON 2.3, ActiveSupport 5.2.4.3 #23

## [1.0.1] - 2020-05-06
### Changed

Add logging method to base collector #18
manageiq-loggers to 0.5.0 #19
manageiq-loggers to >= 0.4.2 #20

## [1.0.0] - 2020-03-19
### Initial release to rubygems.org

[Unreleased]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v2.1.3...HEAD
[2.1.3]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v2.1.2...v2.1.3
[2.1.2]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.12...v2.0.0
[1.0.12]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.11...v1.0.12
[1.0.11]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.9...v1.0.10
[1.0.9]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/RedHatInsights/topological_inventory-providers-common/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/RedHatInsights/topological_inventory-providers-common/releases/v1.0.0
