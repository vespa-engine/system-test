apiVersion: v1
kind: ServiceAccount
metadata:
  name: vespa-tester
  annotations: 
    eks.amazonaws.com/role-arn: arn:aws:iam::__AWS_ACCOUNT__:role/vespa-tester
  
  
