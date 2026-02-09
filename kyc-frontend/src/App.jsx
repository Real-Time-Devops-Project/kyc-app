import { useState } from 'react'
import axios from 'axios'
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

        try {
            // Real API Call
            // Nginx proxy handles routing to the correct service
            const response = await axios.post('/api/ekyc/verify', {
                aadhaar: '123412341234', // In a real app, this would come from state/input
                name: 'Test User'        // In a real app, this would come from state/input
            });

            if (response.data.status === 'VERIFIED') {
                setStatus('success');
            } else {
                alert('Verification Failed');
                setStatus('idle');
            }
        } catch (error) {
            console.error('eKYC Error:', error);
            alert('Error connecting to eKYC service');
            setStatus('idle');
        }
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

    const startCall = async () => {
        setStatus('connecting');
        try {
            // Real API Call
            const response = await axios.post('/api/vkyc/initiate', {
                customerName: 'Test User' // From auth context usually
            });

            if (response.data.sessionId) {
                setStatus('connected');
                // In a real app, you'd use the sessionId to connect to a WebSocket/WebRTC
            }
        } catch (error) {
            console.error('vKYC Error:', error);
            alert('Error initiating vKYC session');
            setStatus('idle');
        }
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
