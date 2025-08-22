package syncnode

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/event"
	"github.com/ethereum-optimism/optimism/op-service/testlog"
	"github.com/ethereum-optimism/optimism/op-supervisor/supervisor/backend/superevents"
	"github.com/ethereum-optimism/optimism/op-supervisor/supervisor/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/require"
)

func TestEventResponse(t *testing.T) {
	chainID := eth.ChainIDFromUInt64(1)
	logger := testlog.Logger(t, log.LvlInfo)
	syncCtrl := &mockSyncControl{}
	backend := &mockBackend{}

	ex := event.NewGlobalSynchronous(context.Background())
	eventSys := event.NewSystem(logger, ex)

	mon := &eventMonitor{}
	eventSys.Register("monitor", mon)

	node := NewManagedNode(logger, chainID, syncCtrl, backend, false)
	eventSys.Register("node", node)

	emitter := eventSys.Register("test", nil)

	crossUnsafe := 0
	crossSafe := 0
	finalized := 0

	nodeExhausted := 0

	// the node will call UpdateCrossUnsafe when a cross-unsafe event is received from the database
	syncCtrl.updateCrossUnsafeFn = func(ctx context.Context, id eth.BlockID) error {
		crossUnsafe++
		return nil
	}
	// the node will call UpdateCrossSafe when a cross-safe event is received from the database
	syncCtrl.updateCrossSafeFn = func(ctx context.Context, derived eth.BlockID, source eth.BlockID) error {
		crossSafe++
		return nil
	}
	// the node will call UpdateFinalized when a finalized event is received from the database
	syncCtrl.updateFinalizedFn = func(ctx context.Context, id eth.BlockID) error {
		finalized++
		return nil
	}

	// the node will call ProvideL1 when the node is exhausted and needs a new L1 derivation source
	syncCtrl.provideL1Fn = func(ctx context.Context, nextL1 eth.BlockRef) error {
		nodeExhausted++
		return nil
	}

	node.Start()

	// send events and continue to do so until at least one of each type has been received
	require.Eventually(t, func() bool {
		testCtx := context.Background()
		// send in one event of each type
		emitter.Emit(testCtx, superevents.CrossUnsafeUpdateEvent{ChainID: chainID})
		emitter.Emit(testCtx, superevents.CrossSafeUpdateEvent{ChainID: chainID})
		emitter.Emit(testCtx, superevents.FinalizedL2UpdateEvent{ChainID: chainID})

		syncCtrl.subscribeEvents.Send(&types.IndexingEvent{
			UnsafeBlock: &eth.BlockRef{Number: 1}})
		syncCtrl.subscribeEvents.Send(&types.IndexingEvent{
			DerivationUpdate: &types.DerivedBlockRefPair{Source: eth.BlockRef{Number: 1}, Derived: eth.BlockRef{Number: 2}}})
		syncCtrl.subscribeEvents.Send(&types.IndexingEvent{
			ExhaustL1: &types.DerivedBlockRefPair{Source: eth.BlockRef{Number: 1}, Derived: eth.BlockRef{Number: 2}}})
		syncCtrl.subscribeEvents.Send(&types.IndexingEvent{
			DerivationOriginUpdate: &eth.BlockRef{Number: 1}})

		require.NoError(t, ex.Drain())

		return crossUnsafe >= 1 &&
			crossSafe >= 1 &&
			finalized >= 1 &&
			mon.receivedLocalUnsafe >= 1 &&
			mon.localDerived >= 1 &&
			nodeExhausted >= 1 &&
			mon.localDerivedOriginUpdate >= 1
	}, 4*time.Second, 250*time.Millisecond)
}
