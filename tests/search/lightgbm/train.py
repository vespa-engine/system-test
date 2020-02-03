#! /usr/bin/env python3
# coding: utf-8

import json
import random

import lightgbm as lgb
import numpy as np
import pandas as pd


def category_value(arr):
    values = { np.NaN: 0, "a":1, "b":2, "c":3, "d":4, "e":5, "i":1, "j":2, "k":3, "l":4, "m":5 }
    return np.array([ 0.21 * values[i] for i in arr ])

# Create training set
num_train_examples = 100000
missing_prob = 0.01
features = pd.DataFrame({
                "numerical_1":   np.random.random(num_train_examples),
                "numerical_2":   np.random.random(num_train_examples),
                "categorical_1": pd.Series(np.random.permutation(["a", "b", "c", "d", "e"] * int(num_train_examples/5)), dtype="category"),
                "categorical_2": pd.Series(np.random.permutation(["i", "j", "k", "l", "m"] * int(num_train_examples/5)), dtype="category"),
           })

# randomly insert missing values
for i in range(int(num_train_examples * len(features.columns) * missing_prob)):
    features.loc[random.randint(0, num_train_examples-1), features.columns[random.randint(0, len(features.columns)-1)]] = None

# create targets (with 0.0 as default for missing values)
target = features["numerical_1"] + features["numerical_2"] + category_value(features["categorical_1"]) + category_value(features["categorical_2"])
target = (target > 2.24) * 1.0
lgb_train = lgb.Dataset(features, target)

# Train model
params = {
    'objective': 'binary',
    'metric': 'binary_logloss',
    'num_leaves': 5,
}
model = lgb.train(params, lgb_train, num_boost_round=20)

# Save model
with open("app/models/lightgbm_classification.json", "w") as f:
    json.dump(model.dump_model(), f, indent=2)

# Predict (for comparison with Vespa evaluation)
num_test_examples = 100
missing_prob = 0.10
test_data = pd.DataFrame({
                "numerical_1":   np.random.random(num_test_examples),
                "numerical_2":   np.random.random(num_test_examples),
                "categorical_1": pd.Series(np.random.permutation(["a", "b", "c", "d", "e"] * int(num_test_examples/5)), dtype="category"),
                "categorical_2": pd.Series(np.random.permutation(["i", "j", "k", "l", "m"] * int(num_test_examples/5)), dtype="category"),
           })
# randomly insert missing values
for i in range(int(num_test_examples * len(test_data.columns) * missing_prob)):
    test_data.loc[random.randint(0, num_test_examples-1), test_data.columns[random.randint(0, len(test_data.columns)-1)]] = None

predictions = model.predict(test_data)
test_data.insert(4, "expected", predictions)

vespa_feed = []
for i in range(num_test_examples):
    fields = {}
    fields["expected"] = test_data.loc[i]["expected"]
    if (not pd.isna(test_data.loc[i]["numerical_1"])):
        fields["num_1"] = test_data.loc[i]["numerical_1"]
    if (not pd.isna(test_data.loc[i]["numerical_2"])):
        fields["num_2"] = test_data.loc[i]["numerical_2"]
    if (not pd.isna(test_data.loc[i]["categorical_1"])):
        fields["cat_1"] = test_data.loc[i]["categorical_1"]
    if (not pd.isna(test_data.loc[i]["categorical_2"])):
        fields["cat_2"] = test_data.loc[i]["categorical_2"]

    doc = { "id": "id:lightgbm:lightgbm::%d" % (i+1), "fields": fields }
    vespa_feed.append(doc)

with open("feed.json", "w") as f:
    json.dump(vespa_feed, f, indent=2)



