# Copyright Vespa.ai. All rights reserved.
import onnx
from onnx import helper, TensorProto

INPUT_1 = helper.make_tensor_value_info('input1', TensorProto.FLOAT, [1])
INPUT_2 = helper.make_tensor_value_info('input2', TensorProto.FLOAT, [1])
OUTPUT = helper.make_tensor_value_info('output', TensorProto.FLOAT, [1])

nodes = [
    helper.make_node(
        'Add',
        ['input1', 'input2'],
        ['output'],
    ),
]
graph_def = helper.make_graph(
    nodes,
    'simple_scoring',
    [
        INPUT_1,
        INPUT_2
    ],
    [OUTPUT],
)
model_def = helper.make_model(graph_def, producer_name='simple.py')
onnx.save(model_def, 'simple.onnx')
