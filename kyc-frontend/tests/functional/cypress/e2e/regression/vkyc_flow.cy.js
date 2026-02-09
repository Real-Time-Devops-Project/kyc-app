describe('vKYC Flow', () => {
    it('Should initiate a video call', () => {
        cy.visit('/');
        cy.contains('Start vKYC').click();

        cy.contains('Start Video Call').click();

        // Should show "Connecting..." then "End Call"
        cy.contains('Connecting to agent...').should('exist');
        // Mock the API to be fast or wait
        cy.intercept('POST', '/api/vkyc/initiate', { body: { sessionId: '123' } }).as('initCall');

        // Verify transition to connected state
        cy.contains('End Call').should('be.visible');
    });
});
