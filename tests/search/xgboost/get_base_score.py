#!/usr/bin/env python3

from sklearn import datasets
import xgboost as xgb
import json
import sys

breast_cancer = datasets.load_breast_cancer()

c = xgb.XGBClassifier(n_estimators=20, objective='binary:logistic')
c.fit(breast_cancer.data,breast_cancer.target)

# Print base score for binary_breast_cancer

bst = c.get_booster()
config_str = bst.save_config()
config = json.loads(config_str)
base_score_str = config['learner']['learner_model_param']['base_score']
print(f"base_score node = {base_score_str}", file=sys.stderr)
base_score_val = json.loads(base_score_str)
base_score = float(base_score_val[0]) if isinstance(base_score_val, list) else float(base_score_val)
print(f"{base_score}")
