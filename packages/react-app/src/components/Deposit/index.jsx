import { useContractReader } from "eth-hooks";
import Balance from "../Balance";
import "./index.css";
import { Button, Input, notification } from "antd";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import { useState } from "react";
import PPCountDown from "../CountDown";
const { ethers } = require("ethers");

export default function Deposit({ provider, price, readContracts, writeContracts, isCorrectNetwork, userSigner, tx }) {
  const [guess, setGuess] = useState();
  const [bet, setBet] = useState();
  const [loading, setLoading] = useState(false);
  const [depositHash, setDepositHash] = useState();

  const duration = useContractReader(readContracts, APP_NAME, "betPeriodSeconds", [], RPC_POLL_TIME);
  const roundId = useContractReader(readContracts, APP_NAME, "roundId", [], RPC_POLL_TIME);
  const roundStartedAt = useContractReader(readContracts, APP_NAME, "roundStartedAt", [], RPC_POLL_TIME);
  const contractAddress = readContracts[APP_NAME]?.address;

  const onGuessChange = e => {
    setGuess(e.target.value);
  };

  const onBetChange = e => {
    setBet(e.target.value);
  };

  const deposit = async () => {
    if (!(provider && userSigner)) {
      notification["error"]({
        message: "Please connect your wallet first!",
      });
      return;
    }

    if (!isCorrectNetwork) {
      notification["error"]({
        message: "Please switch to Goerli first!",
      });
      return;
    }

    if (!guess) {
      notification["error"]({
        message: "Please make your guess!",
      });
      return;
    }

    if (!bet || bet < 0.01) {
      notification["error"]({
        message: "Please deposit at minimum 0.01 ETH to make a guess!",
      });
      return;
    }

    setLoading(true);

    const value = ethers.utils.parseEther(bet.toString());
    const finalGuess = parseInt(parseFloat(guess) * 100);

    const result = tx(writeContracts.PricePrizePool.deposit(finalGuess, { value: value }), update => {
      if (update) {
        setDepositHash(update.hash);
      }
      setLoading(false);
    });
  };

  const now = new Date();
  const guessingEndTime = roundStartedAt && duration ? (parseInt(roundStartedAt) + parseInt(duration)) * 1000 : 0;
  const guessingTimeIsOver = now.getTime() > guessingEndTime;
  const roundOverTime = guessingEndTime + 3600 * 24 * 1000;
  const roundIsOver = roundOverTime < now.getTime();

  return (
    <div className="deposit-wrapper">
      <div className="round-id">Round #{roundId}</div>
      <div className="pool-balance">
        <Balance address={contractAddress ?? ""} provider={provider} price={price} size={88} />
      </div>
      <div className="balance-info">IN PRIZE POOL</div>
      {guessingEndTime && !guessingTimeIsOver && (
        <PPCountDown date={guessingEndTime} completedText="Guessing time is over! Please wait for next round." />
      )}
      {guessingEndTime && guessingTimeIsOver && (
        <>
          {!roundIsOver && (
            <div style={{ color: "#f3ec78" }}>
              Guessing time is over! The final ETH price will be set and next round will start in
            </div>
          )}
          <PPCountDown date={roundOverTime} completedText="Please refresh to enter next round" />
        </>
      )}
      <div className="deposit-form">
        <Input
          addonBefore="USD"
          type="number"
          placeholder={"My Guess: " + price}
          onChange={onGuessChange}
          value={guess}
        />
        <Input addonAfter="ETH" type="number" placeholder="My Bet: Minimum 0.01" onChange={onBetChange} value={bet} />
        <Button className="deposit-btn" type="primary" onClick={deposit} loading={loading}>
          Deposit
        </Button>
        {depositHash && (
          <a
            target="_blank"
            style={{ marginTop: "4px", textDecoration: "underline", display: "block" }}
            href={"https://goerli.etherscan.io/tx/" + depositHash}
            rel="noreferrer"
          >
            {depositHash}
          </a>
        )}
        <a
          href="https://jojos-metaverse.gitbook.io/priceprizepool/"
          target="_blank"
          className="instructions"
          rel="noreferrer"
        >
          HOW TO PLAY?
        </a>
      </div>
    </div>
  );
}
