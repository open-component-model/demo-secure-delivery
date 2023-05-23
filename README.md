## OCM Controller Demo

### Setup

`cd 00-setup-demo && make run`

## Create Component

`cd 01-create-component && make run`

## Verify

ocm resources:
`kubectl get cv,lz,cfg,fd -n ocm-system`

application:
`kubectl get po -n default`

## Teardown

`cd 00-setup-demo && make teardown`
