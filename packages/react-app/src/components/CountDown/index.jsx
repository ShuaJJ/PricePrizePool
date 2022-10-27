import Countdown, { zeroPad } from "react-countdown";
import "./index.css";

export default function PPCountDown({ date, completedText }) {
  const countDown = ({ hours, minutes, seconds, completed }) => {
    if (completed) {
      // Render a completed state
      return <div style={{ color: "#f3ec78" }}>{completedText}</div>;
    } else {
      // Render a countdown
      return (
        <div className="count-down">
          <span className="count-down-item">{zeroPad(hours)}</span> :
          <span className="count-down-item">{zeroPad(minutes)}</span> :
          <span className="count-down-item">{zeroPad(seconds)}</span>
        </div>
      );
    }
  };

  return <Countdown date={date} renderer={countDown} />;
}
