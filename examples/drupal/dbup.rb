# Fact: dbup
#
# Purpose: Returns true
#
# Resolution: Simply returns true
#
# Caveats: None
#

Facter.add(:dbup) do
  setcode do
    true
  end
end
