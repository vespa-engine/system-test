from sklearn import datasets
import xgboost as xgb
import json
import sys

featureMapFile = sys.argv[1]
modelDir = sys.argv[2]
feedDir = sys.argv[3]
predictionFile = sys.argv[4]

def makeVespaFeed(dataset, data):
  datapoints = []
  for i in range(0,len(data)):
    x = data[i]
    doc = {
        "put": "id:%s:x::%i" % (dataset,i), 
        "fields": {
            "id" : i, 
            "features": x.tolist(),
            "dataset": dataset
        }
    }
    datapoints.append(doc)
  return datapoints    
  

diabetes = datasets.load_diabetes()
breast_cancer = datasets.load_breast_cancer()

json.dump(makeVespaFeed("diabetes",diabetes.data), open(feedDir + "diabetes-feed.json","w"))
json.dump(makeVespaFeed("breast_cancer",breast_cancer.data), open(feedDir + "breast_cancer-feed.json","w"))

d = xgb.XGBRegressor(n_estimators=20, objective="reg:squarederror", base_score=0.0)
d .fit(diabetes.data,diabetes.target)
d.get_booster().dump_model(modelDir + "regression_diabetes.json", fmap=featureMapFile, dump_format='json')

b = xgb.XGBRegressor(n_estimators=20, objective="reg:logistic", base_score=0.5)
b.fit(breast_cancer.data,breast_cancer.target)
b.get_booster().dump_model(modelDir + "regression_breast_cancer.json", fmap=featureMapFile, dump_format='json')

c = xgb.XGBClassifier(n_estimators=20, objective='binary:logistic')
c.fit(breast_cancer.data,breast_cancer.target) 
c.get_booster().dump_model(modelDir + "binary_breast_cancer.json", fmap=featureMapFile, dump_format='json')

#predictions
predictions = {
    "regression_diabetes" :  d.predict(diabetes.data).tolist(),
    "regression_breast_cancer" : b.predict(breast_cancer.data).tolist(),
    "binary_breast_cancer" : c.predict_proba(breast_cancer.data)[:,1].tolist()
}
json.dump(predictions,open(predictionFile,"w"))

