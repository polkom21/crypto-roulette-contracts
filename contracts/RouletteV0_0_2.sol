// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFV2PlusWrapper} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";

contract RouletteV0_0_2 is Initializable, OwnableUpgradeable {
    error OnlyVRFWrapperCanFulfill(address have, address want);
    error AlreadyFilled(uint256 _requestId);

    LinkTokenInterface internal i_linkToken;
    IVRFV2PlusWrapper public i_vrfV2PlusWrapper;

    IERC20 public token;
    uint8 public feeBps;

    uint8[3][] public streets;

    uint8[18] public red;

    uint8[18] public black;

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
    event FeeCharge(uint256 amount);
    event BetsResult(uint256 requestId, uint8 result, uint256 wonAmount);
    event FeeWithdrawn(address by, uint256 amount);
    event EmergencyWithdrawn(address by, address token, uint256 amount);
    event FeeChanged(uint8 newFeeBps);

    // requestId => bets
    mapping(uint256 => Bet[]) public bets;
    // requestId => owner
    mapping(uint256 => address) public betsOwner;
    // requestId => bool
    mapping(uint256 => bool) public fulfilled;

    uint256 public feeAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _token,
        address _vrfV2PlusWrapper
    ) public initializer {
        _init(_token, _vrfV2PlusWrapper);
    }

    function _init(IERC20 _token, address _vrfV2PlusWrapper) internal {
        token = _token;
        IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(
            _vrfV2PlusWrapper
        );
        feeAmount = 0;
        feeBps = 0;

        i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
        i_vrfV2PlusWrapper = vrfV2PlusWrapper;
        __Ownable_init(msg.sender);

        streets = [
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

        red = [
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

        black = [
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
            if (
                _bets[i].betType == BetType.ZERO ||
                _bets[i].betType == BetType.DOUBLE_ZERO ||
                _bets[i].betType == BetType.FIRST_COLUMN ||
                _bets[i].betType == BetType.SECOND_COLUMN ||
                _bets[i].betType == BetType.THIRD_COLUMN ||
                _bets[i].betType == BetType.FIRST_DOZEN ||
                _bets[i].betType == BetType.SECOND_DOZEN ||
                _bets[i].betType == BetType.THIRD_DOZEN ||
                _bets[i].betType == BetType.ONE_TO_EIGHTEEN ||
                _bets[i].betType == BetType.NINETEEN_TO_THIRTY_SIX ||
                _bets[i].betType == BetType.EVEN ||
                _bets[i].betType == BetType.ODD ||
                _bets[i].betType == BetType.RED ||
                _bets[i].betType == BetType.BLACK
            ) {
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

            totalAmount += _bets[i].amount;
        }
        uint256 betFee = (totalAmount * feeBps) / 10000;
        feeAmount += betFee;

        require(
            token.balanceOf(address(this)) - feeAmount >= totalAmount * 36,
            "Too high sum of bids to withdraw rewards"
        );

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
        emit FeeCharge(betFee);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal {
        if (fulfilled[_requestId]) revert AlreadyFilled(_requestId);
        // Convert random word to a number between 0 and 37 - from 0 to 36 and 37 for double zero
        uint8 winNumber = uint8(_randomWords[0] % 38);

        fulfilled[_requestId] = true;
        uint256 rewards = 0;
        for (uint256 i = 0; i < bets[_requestId].length; i++) {
            rewards += getWinValue(bets[_requestId][i], winNumber);
        }

        if (rewards > 0) {
            token.transfer(betsOwner[_requestId], rewards);
        }

        emit BetsResult(_requestId, winNumber, rewards);
    }

    receive() external payable {}
    
    fallback() external payable {}

    function withdrawFunds(address _token, uint256 _amount) external onlyOwner {
        emit EmergencyWithdrawn(msg.sender, _token, _amount);
        if (_token == address(0)) {
            payable(owner()).transfer(_amount);
        } else {
            IERC20(_token).transfer(owner(), _amount);
        }
    }

    function withdrawFee() external onlyOwner {
        uint256 amountToWithdraw = feeAmount;
        feeAmount = 0;
        emit FeeWithdrawn(msg.sender, amountToWithdraw);
        token.transfer(owner(), amountToWithdraw);
    }

    function changeFeeBps(uint8 _newFeeBps) external onlyOwner {
        feeBps = _newFeeBps;
        emit FeeChanged(_newFeeBps);
    }

    // VRFV2PlusWrapperConsumerBase

    /**
     * @dev Requests randomness from the VRF V2+ wrapper.
     *
     * @param _callbackGasLimit is the gas limit that should be used when calling the consumer's
     *        fulfillRandomWords function.
     * @param _requestConfirmations is the number of confirmations to wait before fulfilling the
     *        request. A higher number of confirmations increases security by reducing the likelihood
     *        that a chain re-org changes a published randomness outcome.
     * @param _numWords is the number of random words to request.
     *
     * @return requestId is the VRF V2+ request ID of the newly created randomness request.
     */
    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function requestRandomness(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes memory extraArgs
    ) internal returns (uint256 requestId, uint256 reqPrice) {
        reqPrice = i_vrfV2PlusWrapper.calculateRequestPrice(
            _callbackGasLimit,
            _numWords
        );
        i_linkToken.transferAndCall(
            address(i_vrfV2PlusWrapper),
            reqPrice,
            abi.encode(
                _callbackGasLimit,
                _requestConfirmations,
                _numWords,
                extraArgs
            )
        );
        return (i_vrfV2PlusWrapper.lastRequestId(), reqPrice);
    }

    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function requestRandomnessPayInNative(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes memory extraArgs
    ) internal returns (uint256 requestId, uint256 requestPrice) {
        requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(
            _callbackGasLimit,
            _numWords
        );
        return (
            i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(
                _callbackGasLimit,
                _requestConfirmations,
                _numWords,
                extraArgs
            ),
            requestPrice
        );
    }

    function rawFulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) external {
        address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
        if (msg.sender != vrfWrapperAddr) {
            revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
        }
        fulfillRandomWords(_requestId, _randomWords);
    }

    // /// @notice getBalance returns the native balance of the consumer contract
    // function getBalance() public view returns (uint256) {
    //     return address(this).balance;
    // }

    // /// @notice getLinkToken returns the link token contract
    // function getLinkToken() public view returns (LinkTokenInterface) {
    //     return i_linkToken;
    // }
}
