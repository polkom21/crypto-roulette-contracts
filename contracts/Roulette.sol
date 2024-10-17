// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Roulette is Initializable, VRFV2PlusWrapperConsumerBase {
    IERC20 public token;

    uint8[3][] public streets = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [10, 11, 12],
        [13, 14, 15],
        [16, 17, 18],
        [19, 20, 21],
        [22, 23, 24],
        [25, 26, 27],
        [28, 29, 30],
        [31, 32, 33],
        [34, 35, 36]
    ];

    uint8[18] public red = [
        1,
        3,
        5,
        7,
        9,
        12,
        14,
        16,
        18,
        19,
        21,
        23,
        25,
        27,
        30,
        32,
        34,
        36
    ];

    uint8[18] public black = [
        2,
        4,
        6,
        8,
        10,
        11,
        13,
        15,
        17,
        20,
        22,
        24,
        26,
        28,
        29,
        31,
        33,
        35
    ];

    enum BetType {
        ZERO, // 0
        DOUBLE_ZERO, // 37 (00)
        STREET,
        ROW,
        BASKET_US,
        SPLIT,
        CORNER,
        DOUBLE_STREET,
        STRAIGHT_UP,
        FIRST_COLUMN,
        SECOND_COLUMN,
        THIRD_COLUMN,
        FIRST_DOZEN,
        SECOND_DOZEN,
        THIRD_DOZEN,
        ONE_TO_EIGHTEEN,
        NINETEEN_TO_THIRTY_SIX,
        EVEN,
        ODD,
        RED,
        BLACK
    }

    struct Bet {
        uint256 amount;
        uint8[] numbers;
        BetType betType;
    }

    event BetsCreated(uint256 requestId, uint256 feePrice);
    event BetsResult(uint256 requestId, uint8 result, uint256[] winnings);

    // requestId => bets
    mapping(uint256 => Bet[]) public bets;
    // requestId => owner
    mapping(uint256 => address) betsOwner;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor()
        VRFV2PlusWrapperConsumerBase(0x6e6c366a1cd1F92ba87Fd6f96F743B0e6c967Bf0) // Amoy wrapper
    {
        _disableInitializers();
    }

    function initialize(IERC20 _token) public initializer {
        token = _token;
    }

    function isStreetBet(
        uint8 num1,
        uint8 num2,
        uint8 num3
    ) public view returns (bool) {
        for (uint8 i = 0; i < streets.length; i++) {
            if (
                (num1 == streets[i][0] &&
                    num2 == streets[i][1] &&
                    num3 == streets[i][2]) ||
                (num1 == streets[i][0] &&
                    num3 == streets[i][1] &&
                    num2 == streets[i][2]) ||
                (num2 == streets[i][0] &&
                    num1 == streets[i][1] &&
                    num3 == streets[i][2]) ||
                (num2 == streets[i][0] &&
                    num3 == streets[i][1] &&
                    num1 == streets[i][2]) ||
                (num3 == streets[i][0] &&
                    num1 == streets[i][1] &&
                    num2 == streets[i][2]) ||
                (num3 == streets[i][0] &&
                    num2 == streets[i][1] &&
                    num1 == streets[i][2])
            ) {
                return true;
            }
        }
        return false;
    }

    function isSplitBet(uint8 num1, uint8 num2) public pure returns (bool) {
        if (
            (num1 == num2 - 1 && num1 % 3 != 0) ||
            (num2 == num1 - 1 && num2 % 3 != 0)
        ) {
            return true;
        }

        if ((num1 == num2 - 3) || (num2 == num1 - 3)) {
            return true;
        }

        return false;
    }

    function sortNumbers(
        uint8 a,
        uint8 b,
        uint8 c,
        uint8 d
    ) internal pure returns (uint8[4] memory) {
        uint8[4] memory arr = [a, b, c, d];
        for (uint8 i = 0; i < 4; i++) {
            for (uint8 j = i + 1; j < 4; j++) {
                if (arr[i] > arr[j]) {
                    uint8 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
        return arr;
    }

    function sortNumbers(
        uint8 a,
        uint8 b,
        uint8 c,
        uint8 d,
        uint8 e,
        uint8 f
    ) internal pure returns (uint8[6] memory) {
        uint8[6] memory arr = [a, b, c, d, e, f];
        for (uint8 i = 0; i < 6; i++) {
            for (uint8 j = i + 1; j < 6; j++) {
                if (arr[i] > arr[j]) {
                    uint8 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
        return arr;
    }

    function isCornerBet(uint8[] memory numbers) public pure returns (bool) {
        uint8[4] memory nums = sortNumbers(
            numbers[0],
            numbers[1],
            numbers[2],
            numbers[3]
        );

        if (
            nums[1] == nums[0] + 1 &&
            nums[2] == nums[0] + 3 &&
            nums[3] == nums[0] + 4
        ) {
            return true;
        }

        return false;
    }

    function isDoubleStreetBet(
        uint8[] memory numbers
    ) public pure returns (bool) {
        uint8[6] memory nums = sortNumbers(
            numbers[0],
            numbers[1],
            numbers[2],
            numbers[3],
            numbers[4],
            numbers[5]
        );

        if (
            nums[0] % 3 == 1 &&
            nums[1] == nums[0] + 1 &&
            nums[2] == nums[0] + 2 &&
            nums[3] == nums[0] + 3 &&
            nums[4] == nums[0] + 4 &&
            nums[5] == nums[0] + 5
        ) {
            return true;
        }

        return false;
    }

    function getWinValue(
        Bet memory bet,
        uint8 winNumber
    ) internal view returns (uint256 rewards) {
        rewards = 0;
        if (bet.betType == BetType.ZERO) {
            if (winNumber == 0) {
                rewards = bet.amount * 36;
            }
        }
        if (bet.betType == BetType.DOUBLE_ZERO) {
            if (winNumber == 37) {
                rewards = bet.amount * 36;
            }
        }
        if (bet.betType == BetType.STREET) {
            for (uint256 i = 0; i < bet.numbers.length; i++) {
                if (bet.numbers[i] == winNumber) {
                    rewards = bet.amount * 12;
                    break;
                }
            }
        }
        // if (bet.betType == BetType.ROW) {
        //     for (uint256 i = 0; i < bet.numbers.length; i++) {
        //         if (bet.numbers[i] == winNumber) {
        //             rewards = bet.amount * 3;
        //             break;
        //         }
        //     }
        // }
        // if (bet.betType == BetType.BASKET_US) {
        //     for (uint256 i = 0; i < bet.numbers.length; i++) {
        //         if (bet.numbers[i] == winNumber) {
        //             rewards = bet.amount * 7;
        //             break;
        //         }
        //     }
        // }
        if (bet.betType == BetType.SPLIT) {
            for (uint256 i = 0; i < bet.numbers.length; i++) {
                if (bet.numbers[i] == winNumber) {
                    rewards = bet.amount * 18;
                    break;
                }
            }
        }
        if (bet.betType == BetType.CORNER) {
            for (uint256 i = 0; i < bet.numbers.length; i++) {
                if (bet.numbers[i] == winNumber) {
                    rewards = bet.amount * 9;
                    break;
                }
            }
        }
        if (bet.betType == BetType.DOUBLE_STREET) {
            for (uint256 i = 0; i < bet.numbers.length; i++) {
                if (bet.numbers[i] == winNumber) {
                    rewards = bet.amount * 6;
                    break;
                }
            }
        }
        if (bet.betType == BetType.STRAIGHT_UP) {
            if (bet.numbers[0] == winNumber) {
                rewards = bet.amount * 36;
            }
        }
        if (bet.betType == BetType.FIRST_COLUMN) {
            uint8[12] memory firstColumn = [
                1,
                4,
                7,
                10,
                13,
                16,
                19,
                22,
                25,
                28,
                31,
                34
            ];
            for (uint256 i = 0; i < firstColumn.length; i++) {
                if (firstColumn[i] == winNumber) {
                    rewards = bet.amount * 3;
                    break;
                }
            }
        }
        if (bet.betType == BetType.SECOND_COLUMN) {
            uint8[12] memory secondColumn = [
                2,
                5,
                8,
                11,
                14,
                17,
                20,
                23,
                26,
                29,
                32,
                35
            ];
            for (uint256 i = 0; i < secondColumn.length; i++) {
                if (secondColumn[i] == winNumber) {
                    rewards = bet.amount * 3;
                    break;
                }
            }
        }
        if (bet.betType == BetType.THIRD_COLUMN) {
            uint8[12] memory thirdColumn = [
                3,
                6,
                9,
                12,
                15,
                18,
                21,
                24,
                27,
                30,
                33,
                36
            ];
            for (uint256 i = 0; i < thirdColumn.length; i++) {
                if (thirdColumn[i] == winNumber) {
                    rewards = bet.amount * 3;
                    break;
                }
            }
        }
        if (bet.betType == BetType.FIRST_DOZEN) {
            if (winNumber >= 1 && winNumber <= 12) {
                rewards = bet.amount * 3;
            }
        }
        if (bet.betType == BetType.SECOND_DOZEN) {
            if (winNumber >= 13 && winNumber <= 24) {
                rewards = bet.amount * 3;
            }
        }
        if (bet.betType == BetType.THIRD_DOZEN) {
            if (winNumber >= 25 && winNumber <= 36) {
                rewards = bet.amount * 3;
            }
        }
        if (bet.betType == BetType.ONE_TO_EIGHTEEN) {
            if (winNumber >= 1 && winNumber <= 18) {
                rewards = bet.amount * 2;
            }
        }
        if (bet.betType == BetType.NINETEEN_TO_THIRTY_SIX) {
            if (winNumber >= 19 && winNumber <= 36) {
                rewards = bet.amount * 2;
            }
        }
        if (bet.betType == BetType.EVEN) {
            if (winNumber % 2 == 0) {
                rewards = bet.amount * 2;
            }
        }
        if (bet.betType == BetType.ODD) {
            if (winNumber % 2 == 1) {
                rewards = bet.amount * 2;
            }
        }
        if (bet.betType == BetType.RED) {
            for (uint256 i = 0; i < red.length; i++) {
                if (red[i] == winNumber) {
                    rewards = bet.amount * 2;
                    break;
                }
            }
        }
        if (bet.betType == BetType.BLACK) {
            for (uint256 i = 0; i < black.length; i++) {
                if (black[i] == winNumber) {
                    rewards = bet.amount * 2;
                    break;
                }
            }
        }
    }

    function newBet(Bet[] calldata _bets) external returns (uint256) {
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _bets.length; i++) {
            if (_bets[i].betType == BetType.ZERO) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.DOUBLE_ZERO) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.STREET) {
                require(_bets[i].numbers.length == 3, "Invalid numbers length");
                require(
                    isStreetBet(
                        _bets[i].numbers[0],
                        _bets[i].numbers[1],
                        _bets[i].numbers[2]
                    ) == true,
                    "Invalid combination"
                );
            }
            if (_bets[i].betType == BetType.ROW) {
                require(
                    _bets[i].numbers.length == 12,
                    "Invalid numbers length"
                );
                require(true == false, "Not implemented");
            }
            if (_bets[i].betType == BetType.BASKET_US) {
                require(_bets[i].numbers.length == 5, "Invalid numbers length");
                require(true == false, "Not implemented");
            }
            if (_bets[i].betType == BetType.SPLIT) {
                require(_bets[i].numbers.length == 2, "Invalid numbers length");
                require(
                    isSplitBet(_bets[i].numbers[0], _bets[i].numbers[1]) ==
                        true,
                    "Invalid combination"
                );
            }
            if (_bets[i].betType == BetType.CORNER) {
                require(_bets[i].numbers.length == 4, "Invalid numbers length");
                require(
                    isCornerBet(_bets[i].numbers) == true,
                    "Invalid combination"
                );
            }
            if (_bets[i].betType == BetType.DOUBLE_STREET) {
                require(_bets[i].numbers.length == 6, "Invalid numbers length");
                require(
                    isDoubleStreetBet(_bets[i].numbers) == true,
                    "Invalid combination"
                );
            }
            if (_bets[i].betType == BetType.STRAIGHT_UP) {
                require(_bets[i].numbers.length == 1, "Invalid numbers length");
            }
            if (_bets[i].betType == BetType.FIRST_COLUMN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.SECOND_COLUMN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.THIRD_COLUMN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.FIRST_DOZEN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.SECOND_DOZEN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.THIRD_DOZEN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.ONE_TO_EIGHTEEN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.NINETEEN_TO_THIRTY_SIX) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.EVEN) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.ODD) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.RED) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }
            if (_bets[i].betType == BetType.BLACK) {
                require(
                    _bets[i].numbers.length == 0,
                    "Numbers not required for this type"
                );
            }

            totalAmount += _bets[i].amount;
        }

        token.transferFrom(msg.sender, address(this), totalAmount);

        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
        );
        uint256 requestId;
        uint256 reqPrice;
        (requestId, reqPrice) = requestRandomnessPayInNative(
            100000,
            3,
            1,
            extraArgs
        );

        for (uint256 i = 0; i < _bets.length; i++) {
            bets[requestId].push(_bets[i]);
        }
        betsOwner[requestId] = msg.sender;
        emit BetsCreated(requestId, reqPrice);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        // Convert random word to a number between 0 and 37 - from 0 to 36 and 37 for double zero
        uint8 winNumber = uint8(_randomWords[0] % 38);

        uint256 rewards = 0;
        for (uint256 i = 0; i < bets[_requestId].length; i++) {
            rewards += getWinValue(bets[_requestId][i], winNumber);
        }

        if (rewards > 0) {
            token.transfer(betsOwner[_requestId], rewards);
        }
    }
}
