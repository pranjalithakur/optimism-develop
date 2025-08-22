// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Solarray } from "scripts/libraries/Solarray.sol";
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";

import { ChainAssertions } from "scripts/deploy/ChainAssertions.sol";
import { Constants as ScriptConstants } from "scripts/libraries/Constants.sol";
import { Types } from "scripts/libraries/Types.sol";

import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IOPContractsManager } from "interfaces/L1/IOPContractsManager.sol";
import { IAddressManager } from "interfaces/legacy/IAddressManager.sol";
import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import { IFaultDisputeGame } from "interfaces/dispute/IFaultDisputeGame.sol";
import { IPermissionedDisputeGame } from "interfaces/dispute/IPermissionedDisputeGame.sol";
import { Claim, Duration, GameType } from "src/dispute/lib/Types.sol";

import { IOptimismPortal2 as IOptimismPortal } from "interfaces/L1/IOptimismPortal2.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
import { IL1CrossDomainMessenger } from "interfaces/L1/IL1CrossDomainMessenger.sol";
import { IL1ERC721Bridge } from "interfaces/L1/IL1ERC721Bridge.sol";
import { IL1StandardBridge } from "interfaces/L1/IL1StandardBridge.sol";
import { IOptimismMintableERC20Factory } from "interfaces/universal/IOptimismMintableERC20Factory.sol";
import { IETHLockbox } from "interfaces/L1/IETHLockbox.sol";

contract DeployOPChainInput is BaseDeployIO {
    address internal _opChainProxyAdminOwner;
    address internal _systemConfigOwner;
    address internal _batcher;
    address internal _unsafeBlockSigner;
    address internal _proposer;
    address internal _challenger;

    // TODO Add fault proofs inputs in a future PR.
    uint32 internal _basefeeScalar;
    uint32 internal _blobBaseFeeScalar;
    uint256 internal _l2ChainId;
    IOPContractsManager internal _opcm;
    string internal _saltMixer;
    uint64 internal _gasLimit;

    // Configurable dispute game inputs
    GameType internal _disputeGameType;
    Claim internal _disputeAbsolutePrestate;
    uint256 internal _disputeMaxGameDepth;
    uint256 internal _disputeSplitDepth;
    Duration internal _disputeClockExtension;
    Duration internal _disputeMaxClockDuration;
    bool internal _allowCustomDisputeParameters;

    uint32 internal _operatorFeeScalar;
    uint64 internal _operatorFeeConstant;

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployOPChainInput: cannot set zero address");
        if (_sel == this.opChainProxyAdminOwner.selector) _opChainProxyAdminOwner = _addr;
        else if (_sel == this.systemConfigOwner.selector) _systemConfigOwner = _addr;
        else if (_sel == this.batcher.selector) _batcher = _addr;
        else if (_sel == this.unsafeBlockSigner.selector) _unsafeBlockSigner = _addr;
        else if (_sel == this.proposer.selector) _proposer = _addr;
        else if (_sel == this.challenger.selector) _challenger = _addr;
        else if (_sel == this.opcm.selector) _opcm = IOPContractsManager(_addr);
        else revert("DeployOPChainInput: unknown selector");
    }

    function set(bytes4 _sel, uint256 _value) public {
        if (_sel == this.basefeeScalar.selector) {
            _basefeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.blobBaseFeeScalar.selector) {
            _blobBaseFeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.l2ChainId.selector) {
            require(_value != 0 && _value != block.chainid, "DeployOPChainInput: invalid l2ChainId");
            _l2ChainId = _value;
        } else if (_sel == this.gasLimit.selector) {
            _gasLimit = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeGameType.selector) {
            _disputeGameType = GameType.wrap(SafeCast.toUint32(_value));
        } else if (_sel == this.disputeMaxGameDepth.selector) {
            _disputeMaxGameDepth = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeSplitDepth.selector) {
            _disputeSplitDepth = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeClockExtension.selector) {
            _disputeClockExtension = Duration.wrap(SafeCast.toUint64(_value));
        } else if (_sel == this.disputeMaxClockDuration.selector) {
            _disputeMaxClockDuration = Duration.wrap(SafeCast.toUint64(_value));
        } else if (_sel == this.operatorFeeScalar.selector) {
            _operatorFeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.operatorFeeConstant.selector) {
            _operatorFeeConstant = SafeCast.toUint64(_value);
        } else {
            revert("DeployOPChainInput: unknown selector");
        }
    }

    function set(bytes4 _sel, string memory _value) public {
        require((bytes(_value).length != 0), "DeployImplementationsInput: cannot set empty string");
        if (_sel == this.saltMixer.selector) _saltMixer = _value;
        else revert("DeployOPChainInput: unknown selector");
    }

    function set(bytes4 _sel, bytes32 _value) public {
        if (_sel == this.disputeAbsolutePrestate.selector) _disputeAbsolutePrestate = Claim.wrap(_value);
        else revert("DeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, bool _value) public {
        if (_sel == this.allowCustomDisputeParameters.selector) _allowCustomDisputeParameters = _value;
        else revert("DeployOPChainInput: unknown selector");
    }

    function opChainProxyAdminOwner() public view returns (address) {
        require(_opChainProxyAdminOwner != address(0), "DeployOPChainInput: not set");
        return _opChainProxyAdminOwner;
    }

    function systemConfigOwner() public view returns (address) {
        require(_systemConfigOwner != address(0), "DeployOPChainInput: not set");
        return _systemConfigOwner;
    }

    function batcher() public view returns (address) {
        require(_batcher != address(0), "DeployOPChainInput: not set");
        return _batcher;
    }

    function unsafeBlockSigner() public view returns (address) {
        require(_unsafeBlockSigner != address(0), "DeployOPChainInput: not set");
        return _unsafeBlockSigner;
    }

    function proposer() public view returns (address) {
        require(_proposer != address(0), "DeployOPChainInput: not set");
        return _proposer;
    }

    function challenger() public view returns (address) {
        require(_challenger != address(0), "DeployOPChainInput: not set");
        return _challenger;
    }

    function basefeeScalar() public view returns (uint32) {
        require(_basefeeScalar != 0, "DeployOPChainInput: not set");
        return _basefeeScalar;
    }

    function blobBaseFeeScalar() public view returns (uint32) {
        require(_blobBaseFeeScalar != 0, "DeployOPChainInput: not set");
        return _blobBaseFeeScalar;
    }

    function l2ChainId() public view returns (uint256) {
        require(_l2ChainId != 0, "DeployOPChainInput: not set");
        require(_l2ChainId != block.chainid, "DeployOPChainInput: invalid l2ChainId");
        return _l2ChainId;
    }

    function startingAnchorRoot() public pure returns (bytes memory) {
        // WARNING: For now always hardcode the starting permissioned game anchor root to 0xdead,
        // and we do not set anything for the permissioned game. This is because we currently only
        // support deploying straight to permissioned games, and the starting root does not
        // matter for that, as long as it is non-zero, since no games will be played. We do not
        // deploy the permissionless game (and therefore do not set a starting root for it here)
        // because to to update to the permissionless game, we will need to update its starting
        // anchor root and deploy a new permissioned dispute game contract anyway.
        //
        // You can `console.logBytes(abi.encode(ScriptConstants.DEFAULT_OUTPUT_ROOT()))` to get the bytes that
        // are hardcoded into `op-chain-ops/deployer/opcm/opchain.go`

        return abi.encode(ScriptConstants.DEFAULT_OUTPUT_ROOT());
    }

    function opcm() public view returns (IOPContractsManager) {
        require(address(_opcm) != address(0), "DeployOPChainInput: not set");
        DeployUtils.assertValidContractAddress(address(_opcm));
        return _opcm;
    }

    function saltMixer() public view returns (string memory) {
        return _saltMixer;
    }

    function gasLimit() public view returns (uint64) {
        return _gasLimit;
    }

    function disputeGameType() public view returns (GameType) {
        return _disputeGameType;
    }

    function disputeAbsolutePrestate() public view returns (Claim) {
        return _disputeAbsolutePrestate;
    }

    function disputeMaxGameDepth() public view returns (uint256) {
        return _disputeMaxGameDepth;
    }

    function disputeSplitDepth() public view returns (uint256) {
        return _disputeSplitDepth;
    }

    function disputeClockExtension() public view returns (Duration) {
        return _disputeClockExtension;
    }

    function disputeMaxClockDuration() public view returns (Duration) {
        return _disputeMaxClockDuration;
    }

    function allowCustomDisputeParameters() public view returns (bool) {
        return _allowCustomDisputeParameters;
    }

    function operatorFeeScalar() public view returns (uint32) {
        return _operatorFeeScalar;
    }

    function operatorFeeConstant() public view returns (uint64) {
        return _operatorFeeConstant;
    }
}

contract DeployOPChainOutput is BaseDeployIO {
    IProxyAdmin internal _opChainProxyAdmin;
    IAddressManager internal _addressManager;
    IL1ERC721Bridge internal _l1ERC721BridgeProxy;
    ISystemConfig internal _systemConfigProxy;
    IOptimismMintableERC20Factory internal _optimismMintableERC20FactoryProxy;
    IL1StandardBridge internal _l1StandardBridgeProxy;
    IL1CrossDomainMessenger internal _l1CrossDomainMessengerProxy;
    IOptimismPortal internal _optimismPortalProxy;
    IETHLockbox internal _ethLockboxProxy;
    IDisputeGameFactory internal _disputeGameFactoryProxy;
    IAnchorStateRegistry internal _anchorStateRegistryProxy;
    IFaultDisputeGame internal _faultDisputeGame;
    IPermissionedDisputeGame internal _permissionedDisputeGame;
    IDelayedWETH internal _delayedWETHPermissionedGameProxy;
    IDelayedWETH internal _delayedWETHPermissionlessGameProxy;

    function set(bytes4 _sel, address _addr) public virtual {
        require(_addr != address(0), "DeployOPChainOutput: cannot set zero address");
        // forgefmt: disable-start
        if (_sel == this.opChainProxyAdmin.selector) _opChainProxyAdmin = IProxyAdmin(_addr) ;
        else if (_sel == this.addressManager.selector) _addressManager = IAddressManager(_addr) ;
        else if (_sel == this.l1ERC721BridgeProxy.selector) _l1ERC721BridgeProxy = IL1ERC721Bridge(_addr) ;
        else if (_sel == this.systemConfigProxy.selector) _systemConfigProxy = ISystemConfig(_addr) ;
        else if (_sel == this.optimismMintableERC20FactoryProxy.selector) _optimismMintableERC20FactoryProxy = IOptimismMintableERC20Factory(_addr) ;
        else if (_sel == this.l1StandardBridgeProxy.selector) _l1StandardBridgeProxy = IL1StandardBridge(payable(_addr)) ;
        else if (_sel == this.l1CrossDomainMessengerProxy.selector) _l1CrossDomainMessengerProxy = IL1CrossDomainMessenger(_addr) ;
        else if (_sel == this.optimismPortalProxy.selector) _optimismPortalProxy = IOptimismPortal(payable(_addr)) ;
        else if (_sel == this.ethLockboxProxy.selector) _ethLockboxProxy = IETHLockbox(payable(_addr)) ;
        else if (_sel == this.disputeGameFactoryProxy.selector) _disputeGameFactoryProxy = IDisputeGameFactory(_addr) ;
        else if (_sel == this.anchorStateRegistryProxy.selector) _anchorStateRegistryProxy = IAnchorStateRegistry(_addr) ;
        else if (_sel == this.faultDisputeGame.selector) _faultDisputeGame = IFaultDisputeGame(_addr) ;
        else if (_sel == this.permissionedDisputeGame.selector) _permissionedDisputeGame = IPermissionedDisputeGame(_addr) ;
        else if (_sel == this.delayedWETHPermissionedGameProxy.selector) _delayedWETHPermissionedGameProxy = IDelayedWETH(payable(_addr)) ;
        else if (_sel == this.delayedWETHPermissionlessGameProxy.selector) _delayedWETHPermissionlessGameProxy = IDelayedWETH(payable(_addr)) ;
        else revert("DeployOPChainOutput: unknown selector");
        // forgefmt: disable-end
    }

    function opChainProxyAdmin() public view returns (IProxyAdmin) {
        DeployUtils.assertValidContractAddress(address(_opChainProxyAdmin));
        return _opChainProxyAdmin;
    }

    function addressManager() public view returns (IAddressManager) {
        DeployUtils.assertValidContractAddress(address(_addressManager));
        return _addressManager;
    }

    function l1ERC721BridgeProxy() public returns (IL1ERC721Bridge) {
        DeployUtils.assertValidContractAddress(address(_l1ERC721BridgeProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_l1ERC721BridgeProxy));
        return _l1ERC721BridgeProxy;
    }

    function systemConfigProxy() public returns (ISystemConfig) {
        DeployUtils.assertValidContractAddress(address(_systemConfigProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_systemConfigProxy));
        return _systemConfigProxy;
    }

    function optimismMintableERC20FactoryProxy() public returns (IOptimismMintableERC20Factory) {
        DeployUtils.assertValidContractAddress(address(_optimismMintableERC20FactoryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_optimismMintableERC20FactoryProxy));
        return _optimismMintableERC20FactoryProxy;
    }

    function l1StandardBridgeProxy() public returns (IL1StandardBridge) {
        DeployUtils.assertValidContractAddress(address(_l1StandardBridgeProxy));
        DeployUtils.assertL1ChugSplashImplementationSet(address(_l1StandardBridgeProxy));
        return _l1StandardBridgeProxy;
    }

    function l1CrossDomainMessengerProxy() public view returns (IL1CrossDomainMessenger) {
        DeployUtils.assertValidContractAddress(address(_l1CrossDomainMessengerProxy));
        DeployUtils.assertResolvedDelegateProxyImplementationSet("OVM_L1CrossDomainMessenger", addressManager());
        return _l1CrossDomainMessengerProxy;
    }

    function optimismPortalProxy() public returns (IOptimismPortal) {
        DeployUtils.assertValidContractAddress(address(_optimismPortalProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_optimismPortalProxy));
        return _optimismPortalProxy;
    }

    function ethLockboxProxy() public returns (IETHLockbox) {
        DeployUtils.assertValidContractAddress(address(_ethLockboxProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_ethLockboxProxy));
        return _ethLockboxProxy;
    }

    function disputeGameFactoryProxy() public returns (IDisputeGameFactory) {
        DeployUtils.assertValidContractAddress(address(_disputeGameFactoryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_disputeGameFactoryProxy));
        return _disputeGameFactoryProxy;
    }

    function anchorStateRegistryProxy() public returns (IAnchorStateRegistry) {
        DeployUtils.assertValidContractAddress(address(_anchorStateRegistryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_anchorStateRegistryProxy));
        return _anchorStateRegistryProxy;
    }

    function faultDisputeGame() public view returns (IFaultDisputeGame) {
        DeployUtils.assertValidContractAddress(address(_faultDisputeGame));
        return _faultDisputeGame;
    }

    function permissionedDisputeGame() public view returns (IPermissionedDisputeGame) {
        DeployUtils.assertValidContractAddress(address(_permissionedDisputeGame));
        return _permissionedDisputeGame;
    }

    function delayedWETHPermissionedGameProxy() public returns (IDelayedWETH) {
        DeployUtils.assertValidContractAddress(address(_delayedWETHPermissionedGameProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_delayedWETHPermissionedGameProxy));
        return _delayedWETHPermissionedGameProxy;
    }

    function delayedWETHPermissionlessGameProxy() public view returns (IDelayedWETH) {
        // TODO: Eventually switch from Permissioned to Permissionless. Add this check back in.
        // DeployUtils.assertValidContractAddress(address(_delayedWETHPermissionlessGameProxy));
        return _delayedWETHPermissionlessGameProxy;
    }
}

contract DeployOPChain is Script {
    // -------- Core Deployment Methods --------

    function run(DeployOPChainInput _doi, DeployOPChainOutput _doo) public {
        IOPContractsManager opcm = _doi.opcm();

        IOPContractsManager.Roles memory roles = IOPContractsManager.Roles({
            opChainProxyAdminOwner: _doi.opChainProxyAdminOwner(),
            systemConfigOwner: _doi.systemConfigOwner(),
            batcher: _doi.batcher(),
            unsafeBlockSigner: _doi.unsafeBlockSigner(),
            proposer: _doi.proposer(),
            challenger: _doi.challenger()
        });
        IOPContractsManager.DeployInput memory deployInput = IOPContractsManager.DeployInput({
            roles: roles,
            basefeeScalar: _doi.basefeeScalar(),
            blobBasefeeScalar: _doi.blobBaseFeeScalar(),
            l2ChainId: _doi.l2ChainId(),
            startingAnchorRoot: _doi.startingAnchorRoot(),
            saltMixer: _doi.saltMixer(),
            gasLimit: _doi.gasLimit(),
            disputeGameType: _doi.disputeGameType(),
            disputeAbsolutePrestate: _doi.disputeAbsolutePrestate(),
            disputeMaxGameDepth: _doi.disputeMaxGameDepth(),
            disputeSplitDepth: _doi.disputeSplitDepth(),
            disputeClockExtension: _doi.disputeClockExtension(),
            disputeMaxClockDuration: _doi.disputeMaxClockDuration()
        });

        vm.broadcast(msg.sender);
        IOPContractsManager.DeployOutput memory deployOutput = opcm.deploy(deployInput);

        vm.label(address(deployOutput.opChainProxyAdmin), "opChainProxyAdmin");
        vm.label(address(deployOutput.addressManager), "addressManager");
        vm.label(address(deployOutput.l1ERC721BridgeProxy), "l1ERC721BridgeProxy");
        vm.label(address(deployOutput.systemConfigProxy), "systemConfigProxy");
        vm.label(address(deployOutput.optimismMintableERC20FactoryProxy), "optimismMintableERC20FactoryProxy");
        vm.label(address(deployOutput.l1StandardBridgeProxy), "l1StandardBridgeProxy");
        vm.label(address(deployOutput.l1CrossDomainMessengerProxy), "l1CrossDomainMessengerProxy");
        vm.label(address(deployOutput.optimismPortalProxy), "optimismPortalProxy");
        vm.label(address(deployOutput.ethLockboxProxy), "ethLockboxProxy");
        vm.label(address(deployOutput.disputeGameFactoryProxy), "disputeGameFactoryProxy");
        vm.label(address(deployOutput.anchorStateRegistryProxy), "anchorStateRegistryProxy");
        // vm.label(address(deployOutput.faultDisputeGame), "faultDisputeGame");
        vm.label(address(deployOutput.permissionedDisputeGame), "permissionedDisputeGame");
        vm.label(address(deployOutput.delayedWETHPermissionedGameProxy), "delayedWETHPermissionedGameProxy");
        // TODO: Eventually switch from Permissioned to Permissionless.
        // vm.label(address(deployOutput.delayedWETHPermissionlessGameProxy), "delayedWETHPermissionlessGameProxy");

        _doo.set(_doo.opChainProxyAdmin.selector, address(deployOutput.opChainProxyAdmin));
        _doo.set(_doo.addressManager.selector, address(deployOutput.addressManager));
        _doo.set(_doo.l1ERC721BridgeProxy.selector, address(deployOutput.l1ERC721BridgeProxy));
        _doo.set(_doo.systemConfigProxy.selector, address(deployOutput.systemConfigProxy));
        _doo.set(
            _doo.optimismMintableERC20FactoryProxy.selector, address(deployOutput.optimismMintableERC20FactoryProxy)
        );
        _doo.set(_doo.l1StandardBridgeProxy.selector, address(deployOutput.l1StandardBridgeProxy));
        _doo.set(_doo.l1CrossDomainMessengerProxy.selector, address(deployOutput.l1CrossDomainMessengerProxy));
        _doo.set(_doo.optimismPortalProxy.selector, address(deployOutput.optimismPortalProxy));
        _doo.set(_doo.ethLockboxProxy.selector, address(deployOutput.ethLockboxProxy));
        _doo.set(_doo.disputeGameFactoryProxy.selector, address(deployOutput.disputeGameFactoryProxy));
        _doo.set(_doo.anchorStateRegistryProxy.selector, address(deployOutput.anchorStateRegistryProxy));
        // _doo.set(_doo.faultDisputeGame.selector, address(deployOutput.faultDisputeGame));
        _doo.set(_doo.permissionedDisputeGame.selector, address(deployOutput.permissionedDisputeGame));
        _doo.set(_doo.delayedWETHPermissionedGameProxy.selector, address(deployOutput.delayedWETHPermissionedGameProxy));
        // TODO: Eventually switch from Permissioned to Permissionless.
        // _doo.set(
        //     _doo.delayedWETHPermissionlessGameProxy.selector,
        // address(deployOutput.delayedWETHPermissionlessGameProxy)
        // );

        checkOutput(_doi, _doo);
    }

    function checkOutput(DeployOPChainInput _doi, DeployOPChainOutput _doo) public {
        // With 16 addresses, we'd get a stack too deep error if we tried to do this inline as a
        // single call to `Solarray.addresses`. So we split it into two calls.
        address[] memory addrs1 = Solarray.addresses(
            address(_doo.opChainProxyAdmin()),
            address(_doo.addressManager()),
            address(_doo.l1ERC721BridgeProxy()),
            address(_doo.systemConfigProxy()),
            address(_doo.optimismMintableERC20FactoryProxy()),
            address(_doo.l1StandardBridgeProxy()),
            address(_doo.l1CrossDomainMessengerProxy())
        );
        address[] memory addrs2 = Solarray.addresses(
            address(_doo.optimismPortalProxy()),
            address(_doo.disputeGameFactoryProxy()),
            address(_doo.anchorStateRegistryProxy()),
            address(_doo.permissionedDisputeGame()),
            // address(_doo.faultDisputeGame()),
            address(_doo.delayedWETHPermissionedGameProxy()),
            address(_doo.ethLockboxProxy())
        );
        // TODO: Eventually switch from Permissioned to Permissionless. Add this address back in.
        // address(_delayedWETHPermissionlessGameProxy)

        DeployUtils.assertValidContractAddresses(Solarray.extend(addrs1, addrs2));
        assertValidDeploy(_doi, _doo);
    }

    // -------- Deployment Assertions --------
    function assertValidDeploy(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        Types.ContractSet memory proxies = Types.ContractSet({
            L1CrossDomainMessenger: address(_doo.l1CrossDomainMessengerProxy()),
            L1StandardBridge: address(_doo.l1StandardBridgeProxy()),
            L2OutputOracle: address(0),
            DisputeGameFactory: address(_doo.disputeGameFactoryProxy()),
            DelayedWETH: address(_doo.delayedWETHPermissionlessGameProxy()),
            PermissionedDelayedWETH: address(_doo.delayedWETHPermissionedGameProxy()),
            AnchorStateRegistry: address(_doo.anchorStateRegistryProxy()),
            OptimismMintableERC20Factory: address(_doo.optimismMintableERC20FactoryProxy()),
            OptimismPortal: address(_doo.optimismPortalProxy()),
            ETHLockbox: address(_doo.ethLockboxProxy()),
            SystemConfig: address(_doo.systemConfigProxy()),
            L1ERC721Bridge: address(_doo.l1ERC721BridgeProxy()),
            ProtocolVersions: address(0),
            SuperchainConfig: address(0)
        });

        ChainAssertions.checkAnchorStateRegistryProxy(_doo.anchorStateRegistryProxy(), true);
        ChainAssertions.checkDisputeGameFactory(
            _doo.disputeGameFactoryProxy(),
            address(_doi.opChainProxyAdminOwner()),
            address(_doo.permissionedDisputeGame()),
            true
        );
        ChainAssertions.checkL1CrossDomainMessenger(_doo.l1CrossDomainMessengerProxy(), vm, true);
        DeployUtils.assertInitialized({
            _contractAddress: address(_doo.l1ERC721BridgeProxy()),
            _isProxy: true,
            _slot: 0,
            _offset: 0
        });
        DeployUtils.assertInitialized({
            _contractAddress: address(_doo.l1StandardBridgeProxy()),
            _isProxy: true,
            _slot: 0,
            _offset: 0
        });
        DeployUtils.assertInitialized({
            _contractAddress: address(_doo.optimismMintableERC20FactoryProxy()),
            _isProxy: true,
            _slot: 0,
            _offset: 0
        });
        ChainAssertions.checkOptimismPortal2({
            _contracts: proxies,
            _superchainConfig: _doi.opcm().superchainConfig(),
            _opChainProxyAdminOwner: _doi.opChainProxyAdminOwner(),
            _isProxy: true
        });
        DeployUtils.assertInitialized({
            _contractAddress: address(_doo.ethLockboxProxy()),
            _isProxy: true,
            _slot: 0,
            _offset: 0
        });
        ChainAssertions.checkSystemConfig(proxies, _doi, true);
        assertValidAddressManager(_doi, _doo);
        assertValidOPChainProxyAdmin(_doi, _doo);
    }

    function assertValidAddressManager(DeployOPChainInput, DeployOPChainOutput _doo) internal view {
        require(_doo.addressManager().owner() == address(_doo.opChainProxyAdmin()), "AM-10");
    }

    function assertValidOPChainProxyAdmin(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IProxyAdmin admin = _doo.opChainProxyAdmin();
        require(admin.owner() == _doi.opChainProxyAdminOwner(), "OPCPA-10");
        require(
            admin.getProxyImplementation(address(_doo.l1CrossDomainMessengerProxy()))
                == DeployUtils.assertResolvedDelegateProxyImplementationSet(
                    "OVM_L1CrossDomainMessenger", _doo.addressManager()
                ),
            "OPCPA-20"
        );
        require(address(admin.addressManager()) == address(_doo.addressManager()), "OPCPA-30");
        require(
            admin.getProxyImplementation(address(_doo.l1StandardBridgeProxy()))
                == DeployUtils.assertL1ChugSplashImplementationSet(address(_doo.l1StandardBridgeProxy())),
            "OPCPA-40"
        );
        require(
            admin.getProxyImplementation(address(_doo.l1ERC721BridgeProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.l1ERC721BridgeProxy())),
            "OPCPA-50"
        );
        require(
            admin.getProxyImplementation(address(_doo.optimismPortalProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.optimismPortalProxy())),
            "OPCPA-60"
        );
        require(
            admin.getProxyImplementation(address(_doo.systemConfigProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.systemConfigProxy())),
            "OPCPA-70"
        );
        require(
            admin.getProxyImplementation(address(_doo.optimismMintableERC20FactoryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.optimismMintableERC20FactoryProxy())),
            "OPCPA-80"
        );
        require(
            admin.getProxyImplementation(address(_doo.disputeGameFactoryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.disputeGameFactoryProxy())),
            "OPCPA-90"
        );
        require(
            admin.getProxyImplementation(address(_doo.delayedWETHPermissionedGameProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.delayedWETHPermissionedGameProxy())),
            "OPCPA-100"
        );
        require(
            admin.getProxyImplementation(address(_doo.anchorStateRegistryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.anchorStateRegistryProxy())),
            "OPCPA-110"
        );
        require(
            admin.getProxyImplementation(address(_doo.ethLockboxProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.ethLockboxProxy())),
            "OPCPA-120"
        );
    }

    // -------- Utilities --------

    function etchIOContracts() public returns (DeployOPChainInput doi_, DeployOPChainOutput doo_) {
        (doi_, doo_) = getIOContracts();
        vm.etch(address(doi_), type(DeployOPChainInput).runtimeCode);
        vm.etch(address(doo_), type(DeployOPChainOutput).runtimeCode);
    }

    function getIOContracts() public view returns (DeployOPChainInput doi_, DeployOPChainOutput doo_) {
        doi_ = DeployOPChainInput(DeployUtils.toIOAddress(msg.sender, "optimism.DeployOPChainInput"));
        doo_ = DeployOPChainOutput(DeployUtils.toIOAddress(msg.sender, "optimism.DeployOPChainOutput"));
    }
}
