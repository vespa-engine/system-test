#!/usr/bin/env python3

from onnx import TensorProto
from onnx.helper import (
    make_model, make_node, make_graph,
    make_tensor_value_info)
from onnx.checker import check_model

X = make_tensor_value_info('model_input_1', TensorProto.DOUBLE, [2, 2])
A = make_tensor_value_info('model_input_2', TensorProto.DOUBLE, [2])
B = make_tensor_value_info('model_input_3', TensorProto.DOUBLE, [2])
Y = make_tensor_value_info('model_output_1', TensorProto.DOUBLE, [2])

node1 = make_node('MatMul', ['model_input_1', 'model_input_2'], ['XA'])
node2 = make_node('Add', ['XA', 'model_input_3'], ['model_output_1'])

graph = make_graph([node1, node2], 'multiply_add', [X, A, B], [Y])

onnx_model = make_model(graph)

# Generate older version
del onnx_model.opset_import[:]
opset = onnx_model.opset_import.add()
opset.version = 14

check_model(onnx_model)
with open("multiply_add.onnx", "wb") as f:
    f.write(onnx_model.SerializeToString())
print(onnx_model)
