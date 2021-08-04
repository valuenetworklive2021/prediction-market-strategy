//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./StrategyStorage.sol";

contract Checkpoint is StrategyStorage {
    function addCheckpoint(
        address[] memory _users,
        address[] memory _initialAmounts
    ) internal {
        Checkpoint storage newCheckpoint = checkpoints[latestCheckpointId++];
        newCheckpoint.users = _users;
        newCheckpoint.initialAmounts = _initialAmounts;

        emit newCheckpointCreated(latestCheckpointId);
    }

    //ratio = (percentage * 1e4)
    function _bet(uint256 _checkpointId, uint256 ratio)
        internal
        returns (uint256 betAmountAvailable)
    {
        Checkpoint storage checkpointRef = checkpoints[_checkpointId];

        uint256[] memory userAmountAvailable = checkpointRef
            .userAmountAvailable;

        for (uint256 index = 0; index < userAmountAvailable.length; index++) {
            uint256 userProportion = (userAmountAvailable[index] * ratio) / 1e4;
            userAmountAvailable[index] -= userProportion;
            betAmountAvailable += userProportion;
        }

        checkpointRef.totalInvested += betAmountAvailable;
        checkpointRef.totalActiveMarkets++;
    }

    //ratio = totalAmountClaimed* 1e8/totalBetAmountForThatSide
    function _claim(
        uint256 _conditionIndex,
        uint256 ratio,
        uint8 winningSide
    ) internal {
        uint256[] memory marketCheckpoints = conditionIndexToCheckpoints[
            _conditionIndex
        ];
        for (uint256 index = 0; index < marketCheckpoints.length; index++) {
            Checkpoint memory _checkpoint = checkpoints[
                marketCheckpoints[index]
            ];

            uint256 lowBets = markets[_checkpoint][_conditionIndex].lowBets;
            uint256 highBets = markets[_checkpoint][_conditionIndex].highBets;

            if (winningSide == 0 && lowBets > 0) {
                _checkpoint.totalProfit += (lowBets * ratio) / 1e8;
                _checkpoint.totalLoss += highBets;

                totalBetFunds += lowBets;
                totalUserFunds += lowBets;
            } else if (winningSide == 1 && highBets > 0) {
                _checkpoint.totalProfit += (highBets * ratio) / 1e8;
                _checkpoint.totalLoss += lowBets;

                totalBetFunds += highBets;
                totalUserFunds += highBets;
            }

            _updateCheckpointStatus(_checkpoint);
        }
    }

    function _updateCheckpointStatus(Checkpoint memory _checkpoint) internal {
        _checkpoint.totalActiveMarkets--;
        if (_checkpoint.totalActiveMarkets == 0) {
            if (_checkpoint.totalProfit > _checkpoint.totalLoss) {
                _checkpoint.status = true;
            } else {
                _checkpoint.status = false;
            }
            _checkpoint.isSettled = true;
        }
    }
}

/**
    * new checkpoint:
    - add new user 
    - remove user
 */

/**
     * update checkpoint
     - new bet (update total invested, reduceInvested amount from each user total, market (index => BetDetails), totalActiveMarkets++ )
     - claim (update total profit/loss, status (if profit - true, loss - false), totalActiveMarkets--, update BetDetails)
  */

/**
    BetDetails {
        high bets (total amount in high bet)
        low bets  (total amount in low bet)
    }
 */

/**
    settle checkpoint
    - if all markets claimed (if totalActiveMarkets == 0)
    - update settled true 
 */

//Overall
/**
    Markets (index => checkpointId)
    Checkpoints (checkpointId => conditionIds[])
 */
