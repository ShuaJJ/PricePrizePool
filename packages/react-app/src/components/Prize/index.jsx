import { useContractReader } from "eth-hooks";
import "./index.css";
import { Button, Col, Row } from "antd";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import { useState } from "react";
const { ethers } = require("ethers");

export default function Prize({ provider, price, readContracts, writeContracts, isCorrectNetwork, userSigner, tx }) {
  const ethPrice = useContractReader(readContracts, APP_NAME, "ethPrice", [], RPC_POLL_TIME);
  const winningGuess = useContractReader(readContracts, APP_NAME, "winningGuess", [], RPC_POLL_TIME);
  const priceSetAt = useContractReader(readContracts, APP_NAME, "priceSetAt", [], RPC_POLL_TIME);

  const [loading, setLoading] = useState(false);

  const timestamp = priceSetAt?.toString();
  var date;
  if (timestamp) {
    date = new Date(parseInt(priceSetAt?.toString()) * 1000);
  }

  const check = () => {
    setLoading(true);
  };

  return (
    <div className="prize-wrapper">
      <Row className="info-row">
        <Col className="info-col" flex="180px">
          ETH Price
        </Col>
        <Col flex="auto">{ethPrice / 100}</Col>
      </Row>
      <Row className="info-row">
        <Col className="info-col" flex="180px">
          Price Set At
        </Col>
        <Col flex="auto">{date?.toLocaleString()}</Col>
      </Row>
      <Row className="info-row">
        <Col className="info-col" flex="180px">
          Winning Guess
        </Col>
        <Col flex="auto">{winningGuess / 100}</Col>
      </Row>
      <Button className="check-btn" type="primary" onClick={check} loading={loading}>
        Check My Prize
      </Button>
    </div>
  );
}
