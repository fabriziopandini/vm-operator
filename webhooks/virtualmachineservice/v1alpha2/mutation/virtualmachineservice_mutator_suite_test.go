// Copyright (c) 2023 VMware, Inc. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

package mutation_test

import (
	"testing"

	. "github.com/onsi/ginkgo"

	"github.com/vmware-tanzu/vm-operator/test/builder"
	"github.com/vmware-tanzu/vm-operator/webhooks/virtualmachineservice/v1alpha2/mutation"
)

// suite is used for unit and integration testing this webhook.
var suite = builder.NewTestSuiteForMutatingWebhook(
	mutation.AddToManager,
	mutation.NewMutator,
	"default.mutating.virtualmachineservice.v1alpha2.vmoperator.vmware.com")

func TestWebhook(t *testing.T) {
	_ = intgTests
	suite.Register(t, "Mutating webhook suite", intgTests, uniTests)
}

var _ = BeforeSuite(suite.BeforeSuite)

var _ = AfterSuite(suite.AfterSuite)