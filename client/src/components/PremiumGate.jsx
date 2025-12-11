import { useModal } from '@/hooks/useModal';
import PropTypes from 'prop-types';
import './PremiumGate.scss';

/**
 * PremiumGate Component
 * Elegant gate for premium features
 * Shows locked state with upgrade CTA for non-premium users
 */

export default function PremiumGate({
  isPremium = false,
  feature = 'Feature',
  children,
  showBadge = true
}) {
  const premiumModal = useModal('premium-paywall');

  const handleUpgrade = () => {
    premiumModal.openModal({ feature });
  };

  if (isPremium) {
    return <>{children}</>
  }

  return (
    <div className="premium-gate">
      <div className="premium-gate-overlay">
        <div className="premium-gate-content">
          <div className="gate-icon">🔒</div>
          <h3>{feature}</h3>
          <p>Unlock premium features and get unlimited access</p>
          <button className="btn-upgrade" onClick={handleUpgrade}>
            ✨ Upgrade to Premium
          </button>
        </div>
      </div>
      <div className="gate-children-blurred">
        {children}
      </div>
    </div>
  );
}
