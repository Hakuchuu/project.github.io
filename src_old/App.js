import Web3 from "web3";
import logo from './logo.svg';
import './App.css';
import React from 'react';

function App() {
  const obj = {
    name: "Carrot",
    for: "Max",
    details: {
      color: "orange",
      size: 12,
    },
  };
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Name is {obj.name}
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
}

// eslint-disable-next-line
class ShoppingList extends React.Component {
  render() {
    return (
      <div className="shopping-list">
        <h1>Shopping List for {this.props.name}</h1>
        <u1>
          <li>Instagram</li>
          <li>WhatsApp</li>
          <li>Oculus</li>
        </u1>
      </div>
    );
  }
} // Example usage: <ShoppingList name="Mark" />

export default App;
