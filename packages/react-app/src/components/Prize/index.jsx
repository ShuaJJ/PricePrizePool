import { useContractReader } from "eth-hooks";
import "./index.css";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import PPCountDown from "../CountDown";
import RoundInfo from "./RoundInfo";

export default function Prize({ generalInfo, readContracts, writeContracts, address, tx }) {
  const myWinnings = useContractReader(readContracts, APP_NAME, "myWinnings", [address], RPC_POLL_TIME);

  return (
    <div className="prize-page">
      <PPCountDown isPrize={true} generalInfo={generalInfo} />
      <div className="history-title">Last 7 Rounds</div>
      {myWinnings?.map((myWin, index) => (
        <RoundInfo index={index} myWin={myWin} tx={tx} writeContracts={writeContracts} readContracts={readContracts} />
      ))}
    </div>
  );
}
