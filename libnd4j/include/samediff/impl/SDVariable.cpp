/*******************************************************************************
 * Copyright (c) 2015-2018 Skymind, Inc.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

//
// @author raver119@gmail.com
//

#include "../SDVariable.h"
#include "../SameDiff.h"
#include <samediff/samediff_cpp.h>
#include <NDArrayFactory.h>
#include <exceptions/precondition_exception.h>

namespace samediff {
    SDVariable::SDVariable(SameDiff &sd, nd4j::graph::Node *node) {
        precondition_exception::check(node != nullptr, "SDVariable: Node passed in is null");
        precondition_exception::check(node->parentGraph() != nullptr, "SDVariable: Node passed in has no Graph defined");
        _node = node;
        _sd = &sd;
    }

    nd4j::NDArray SDVariable::array() {
        auto var = _node->parentGraph()->getVariableSpace()->getVariable(_node->id(), 0);
        return *var->getNDArray();
    }

    int SDVariable::nodeId() const{
        return _node->id();
    }

    SameDiff* SDVariable::sd() const {
        return _sd;
    }

    SDVariable SDVariable::operator+(const SDVariable& other) const {
        return samediff::arithmetic::Add(*this->_sd, *this, other);
    }
}

samediff::SDVariable operator+(const float &scalar, const samediff::SDVariable &var) {
    auto sd = var.sd();
    auto x = sd->variable(nd4j::NDArrayFactory::create<float>(scalar));
    return samediff::arithmetic::Add(*sd, x, var);
}

samediff::SDVariable operator+(const samediff::SDVariable &var, const float &scalar) {
    auto sd = var.sd();
    auto y = sd->variable(nd4j::NDArrayFactory::create<float>(scalar));
    return samediff::arithmetic::Add(*sd, var, y);
}