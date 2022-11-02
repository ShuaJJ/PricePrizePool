import { useContractReader } from "eth-hooks";
import "./index.css";
import { Button, Col, Divider, Row } from "antd";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import { useState } from "react";
import PPCountDown from "../CountDown";
import TxHashLink from "../TxHashLink";
const { ethers } = require("ethers");

export default function RoundInfo({ index, myWin, tx, writeContracts, readContracts }) {
  const [claimHash, setClaimHash] = useState();
  const roundInfo = useContractReader(readContracts, APP_NAME, "roundRingBuffer", [index], RPC_POLL_TIME);
  var ethPrice, roundId, roundTotal, winningTotal;
  if (roundInfo) {
    roundId = roundInfo[0];
    ethPrice = roundInfo[1];
    roundTotal = ethers.utils.formatEther(roundInfo[2]);
    winningTotal = ethers.utils.formatEther(myWin);
  }

  const [loading, setLoading] = useState(false);

  const check = () => {
    setLoading(true);
    const result = tx(writeContracts.PricePrizePool.claim(roundId), update => {
      if (update) {
        setClaimHash(update.hash);
      }
      setLoading(false);
    });
  };

  if (!roundId || roundId == 0 || ethPrice == 0) {
    return <></>;
  }

  return (
    <div className="prize-wrapper">
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
          Please claim your prizes as soon as possible. The contract will hold it for 7 rounds. After that, the prize
          will be gone!
        </div>
      )}
      {winningTotal > 0 && (
        <Button className="check-btn" type="primary" onClick={check} loading={loading}>
          Claim
        </Button>
      )}
      <TxHashLink hash={claimHash} />
      <Divider />
    </div>
  );
}
