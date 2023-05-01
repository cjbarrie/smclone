import { BrowserRouter as Router, Route, Switch } from "react-router-dom";
import Login from "./components/Login";
import Timeline from "./components/Timeline";

function App() {
  return (
    <Router>
      <Switch>
        <Route exact path="/" component={Login} />
        <Route path="/timeline" component={Timeline} />
      </Switch>
    </Router>
  );
}

export default App;
