// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

contract MockVRFV2PlusWrapper is IVRFV2PlusWrapper {
    uint256 index = 0;
    function calculateRequestPrice(
        uint32 _callbackGasLimit,
        uint32 _numWords
    ) external view returns (uint256) {
        return 100;
    }

    function calculateRequestPriceNative(
        uint32 _callbackGasLimit,
        uint32 _numWords
    ) external view returns (uint256) {
        return 100;
    }

    function estimateRequestPrice(
        uint32 _callbackGasLimit,
        uint32 _numWords,
        uint256 _requestGasPriceWei
    ) external view returns (uint256) {
        return 100;
    }

    function estimateRequestPriceNative(
        uint32 _callbackGasLimit,
        uint32 _numWords,
        uint256 _requestGasPriceWei
    ) external view returns (uint256) {
        return 100;
    }

    function requestRandomWordsInNative(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes calldata extraArgs
    ) external payable returns (uint256 requestId) {
        requestId = index;
        index++;
    }

    function link() external view returns (address) {
        return address(0);
    }

    function linkNativeFeed() external view returns (address) {
        return address(0);
    }

    function lastRequestId() external view returns (uint256) {
        return index;
    }

    function sendRawFulfillRandomWords(address _target, uint256 _requestId, uint256[] memory _randomWords) external {
        VRFV2PlusWrapperConsumerBase(_target).rawFulfillRandomWords(_requestId, _randomWords);
    }
}
