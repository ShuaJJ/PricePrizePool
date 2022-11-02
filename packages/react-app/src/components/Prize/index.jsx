import { useContractReader } from "eth-hooks";
import "./index.css";
import { Button, Col, Row } from "antd";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import { useState } from "react";
import PPCountDown from "../CountDown";
import TxHashLink from "../TxHashLink";
const { ethers } = require("ethers");

export default function Prize({
  generalInfo,
  provider,
  price,
  readContracts,
  guessingEndTime,
  writeContracts,
  isCorrectNetwork,
  userSigner,
  address,
  tx,
}) {
  const [claimHash, setClaimHash] = useState();
  const priceInfo = useContractReader(readContracts, APP_NAME, "priceInfo", [], RPC_POLL_TIME);
  const myWinnings = useContractReader(readContracts, APP_NAME, "myWinnings", [address], RPC_POLL_TIME);
  var ethPrice,
    roundId,
    roundTotal,
    winningTotal = 0;
  if (priceInfo) {
    roundId = priceInfo[0];
    ethPrice = priceInfo[2];
    roundTotal = ethers.utils.formatEther(priceInfo[1]);
    console.log("AAAAA", ethPrice);
    console.log("BBBB", roundTotal);
  }
  if (myWinnings) {
    for (var i = 0; i < myWinnings.length; i++) {
      const win = parseFloat(ethers.utils.formatEther(myWinnings[i]));
      winningTotal += win;
    }
  }

  const [loading, setLoading] = useState(false);

  const check = () => {
    setLoading(true);
    const result = tx(writeContracts.PricePrizePool.claim(), update => {
      if (update) {
        setClaimHash(update.hash);
      }
      setLoading(false);
    });
    console.log("AAAAAA", result);
  };

  return (
    <div className="prize-page">
      <PPCountDown isPrize={true} generalInfo={generalInfo} />
      {ethPrice > 0 && (
        <div className="prize-wrapper">
          <div></div>
          <Row className="info-row">
            <Col className="info-col" flex="180px">
              Round
            </Col>
            <Col flex="auto">{roundId}</Col>
          </Row>
          <Row className="info-row">
            <Col className="info-col" flex="180px">
              Final ETH Price
            </Col>
            <Col flex="auto">${ethPrice}</Col>
          </Row>
          <Row className="info-row">
            <Col className="info-col" flex="180px">
              Round Total Deposit
            </Col>
            <Col flex="auto">{roundTotal} ETH</Col>
          </Row>
          <Row className="info-row">
            <Col className="info-col" flex="230px">
              My Prize(In last 7 rounds)
            </Col>
            <Col flex="auto">{winningTotal} ETH</Col>
          </Row>
          {winningTotal > 0 && (
            <div className="claim-info">
              Please claim your prizes as soon as possible. The contract will hold it for 7 rounds. After that, the
              prize will be gone!
            </div>
          )}
          {winningTotal > 0 && (
            <Button className="check-btn" type="primary" onClick={check} loading={loading}>
              Claim
            </Button>
          )}
          <TxHashLink hash={claimHash} />
        </div>
      )}
    </div>
  );
}
