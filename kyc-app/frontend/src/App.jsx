import { useState } from 'react'
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom'
import './index.css'

// Components
const Home = () => (
    <div className="card">
        <h2>Welcome to the KYC Portal</h2>
        <p>Select a service to proceed.</p>
        <div className="action-buttons">
            <Link to="/ekyc" className="btn-primary">Start eKYC</Link>
            <Link to="/vkyc" className="btn-secondary">Start vKYC</Link>
        </div>
    </div>
);

const EkycForm = () => {
    const [status, setStatus] = useState('idle');

    const handleSubmit = async (e) => {
        e.preventDefault();
        setStatus('submitting');
        // Simulate API call
        setTimeout(() => setStatus('success'), 1500);
    };

    return (
        <div className="card">
            <h2>eKYC Verification</h2>
            {status === 'success' ? (
                <div className="success-message">
                    <h3>Verification Successful!</h3>
                    <p>Your eKYC data has been submitted.</p>
                    <Link to="/" className="btn-text">Back to Home</Link>
                </div>
            ) : (
                <form onSubmit={handleSubmit}>
                    <div className="form-group">
                        <label>Aadhaar Number</label>
                        <input type="text" placeholder="Enter 12-digit Aadhaar" required />
                    </div>
                    <div className="form-group">
                        <label>Full Name</label>
                        <input type="text" placeholder="As per Aadhaar" required />
                    </div>
                    <button type="submit" className="btn-primary" disabled={status === 'submitting'}>
                        {status === 'submitting' ? 'Verifying...' : 'Submit eKYC'}
                    </button>
                </form>
            )}
        </div>
    );
};

const VkycForm = () => {
    const [status, setStatus] = useState('idle');

    const startCall = () => {
        setStatus('connecting');
        setTimeout(() => setStatus('connected'), 2000);
    };

    return (
        <div className="card">
            <h2>Video KYC</h2>
            {status === 'idle' && (
                <div className="vkyc-intro">
                    <p>Ensure you have good lighting and your original documents ready.</p>
                    <button onClick={startCall} className="btn-primary">Start Video Call</button>
                </div>
            )}
            {status === 'connecting' && <div className="loader">Connecting to agent...</div>}
            {status === 'connected' && (
                <div className="video-interface">
                    <div className="video-placeholder">
                        <span>Agent Video Feed</span>
                    </div>
                    <div className="controls">
                        <button className="btn-danger" onClick={() => setStatus('idle')}>End Call</button>
                    </div>
                </div>
            )}
        </div>
    );
};

function App() {
    return (
        <Router>
            <div className="app-container">
                <header className="app-header">
                    <div className="logo">Vision KYC</div>
                    <nav>
                        <Link to="/">Home</Link>
                        <Link to="/ekyc">eKYC</Link>
                        <Link to="/vkyc">vKYC</Link>
                    </nav>
                </header>
                <main className="app-content">
                    <Routes>
                        <Route path="/" element={<Home />} />
                        <Route path="/ekyc" element={<EkycForm />} />
                        <Route path="/vkyc" element={<VkycForm />} />
                    </Routes>
                </main>
            </div>
        </Router>
    )
}

export default App
