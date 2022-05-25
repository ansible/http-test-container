# http-test-container

[![Build Status](https://dev.azure.com/ansible/http-test-container/_apis/build/status/CI?branchName=main)](https://dev.azure.com/ansible/http-test-container/_build/latest?definitionId=6&branchName=main)

HTTP server container for testing. When starting it must be run with `-e KRB5_PASSWORD=MyPassword` to set the password for the default Kerberos account `admin@ANSIBLE.TEST`.
