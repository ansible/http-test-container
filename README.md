# http-test-container

[![Build Status](https://dev.azure.com/ansible/http-test-container/_apis/build/status/CI?branchName=master)](https://dev.azure.com/ansible/http-test-container/_build/latest?definitionId=6&branchName=master)
[![Docker Repository on Quay](https://quay.io/repository/ansible/http-test-container/status "Docker Repository on Quay")](https://quay.io/repository/ansible/http-test-container)

HTTP server container for testing. When starting it must be run with `-e KRB5_PASSWORD=MyPassword` to set the password for the default Kerberos account `admin@ANSIBLE.TEST`.
