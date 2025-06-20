#!/usr/bin/env python3

from onnx import TensorProto, save
from onnx.helper import (
    make_model, make_node, make_graph,
    make_tensor_value_info)
from onnx.checker import check_model

X = make_tensor_value_info('baz', TensorProto.FLOAT, [1])
Y = make_tensor_value_info('xyzzy', TensorProto.FLOAT, [1])
Z = make_tensor_value_info('foo', TensorProto.FLOAT, [1])

node1 = make_node('Add', ['baz', 'xyzzy'], ['foo'])

graph = make_graph([node1], 'add', [X, Y], [Z])

onnx_model = make_model(graph)

check_model(onnx_model)
with open("baz.onnx.serialized", "wb") as f:
    f.write(onnx_model.SerializeToString())
#print(onnx_model)
save(onnx_model, 'baz.onnx')
