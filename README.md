# hive-runner-ios

iOS component for the hive-runner

## Quick start

Install the hive-runner and setup your hive as described in the [hive-runner Readme](https://github.com/bbc/hive-runner/blob/master/README.md).

When presented with the option of adding a module, do so and enter 'ios' as the module name, select yes to retrieve from Github and enter BBC as the account name.

## Configuration file

The configuration file allows you to specify the Development Team, Provisioning Certificate and Signing Identity to use when testing your app, please change these as appropriate:

    ios:
      max_workers: 5
      provisioning_cert: iOS Team Provisioning Profile: *
      development_team:  DEVELOPMENT_TEAM_ID
      signing_identity:  iPhone Developer
